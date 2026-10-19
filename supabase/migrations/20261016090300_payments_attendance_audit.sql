-- Phase 2 / 4 of 6 — payments (append-only), attendance_records, audit_logs (append-only).

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete restrict,
  member_id uuid not null,
  subscription_id uuid,
  kind text not null default 'payment' check (kind in ('payment', 'reversal')),
  reverses_payment_id uuid,
  amount_paise bigint not null check (amount_paise > 0), -- always positive; kind gives the sign
  method text not null check (method in ('cash', 'upi', 'card', 'bank_transfer', 'other')),
  reference text,
  note text,
  paid_at timestamptz not null default now(), -- forced to server now() by trigger
  business_date date not null, -- computed from the gym timezone by trigger
  recorded_by uuid, -- auth user id; deliberately no FK so append-only rows never block user deletion
  created_at timestamptz not null default now(),
  check (
    (kind = 'payment' and reverses_payment_id is null)
    or (kind = 'reversal' and reverses_payment_id is not null)
  ),
  unique (id, gym_id),
  foreign key (member_id, gym_id) references public.members (id, gym_id) on delete restrict,
  foreign key (subscription_id, gym_id, member_id)
    references public.member_subscriptions (id, gym_id, member_id) on delete restrict,
  foreign key (reverses_payment_id, gym_id)
    references public.payments (id, gym_id) on delete restrict
);
create index payments_member_idx on public.payments (member_id, gym_id);
create index payments_subscription_idx on public.payments (subscription_id, gym_id, member_id);
create index payments_reverses_idx on public.payments (reverses_payment_id, gym_id);
create index payments_gym_business_date_idx on public.payments (gym_id, business_date);

create function private.payments_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_orig public.payments;
  v_reversed bigint;
begin
  -- Tamper-proof time: ignore anything the client sent.
  new.paid_at := now();
  new.business_date := private.gym_business_date(new.gym_id, new.paid_at);
  if (select auth.uid()) is not null then
    new.recorded_by := (select auth.uid());
  end if;

  if new.kind = 'reversal' then
    -- Serialise concurrent reversals of the same payment.
    perform pg_advisory_xact_lock(hashtextextended(new.reverses_payment_id::text, 0));

    select * into v_orig
      from public.payments p
      where p.id = new.reverses_payment_id and p.gym_id = new.gym_id;

    if v_orig.id is null or v_orig.kind <> 'payment' then
      raise exception 'a reversal must reference an original payment row' using errcode = '23514';
    end if;
    if v_orig.member_id <> new.member_id
       or v_orig.subscription_id is distinct from new.subscription_id then
      raise exception 'a reversal must match the original payment member and subscription'
        using errcode = '23514';
    end if;

    select coalesce(sum(r.amount_paise), 0) into v_reversed
      from public.payments r
      where r.reverses_payment_id = v_orig.id and r.gym_id = v_orig.gym_id;

    if v_reversed + new.amount_paise > v_orig.amount_paise then
      raise exception 'reversals (% + %) would exceed the original payment (%)',
        v_reversed, new.amount_paise, v_orig.amount_paise using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger payments_before_insert
  before insert on public.payments
  for each row execute function private.payments_before_insert();

create trigger payments_append_only
  before update or delete on public.payments
  for each row execute function private.reject_mutation();

create trigger payments_no_truncate
  before truncate on public.payments
  for each statement execute function private.reject_mutation();

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete restrict,
  member_id uuid not null,
  checked_in_at timestamptz not null default now(), -- forced to server now() by trigger
  business_date date not null, -- computed from the gym timezone by trigger
  recorded_by uuid,
  created_at timestamptz not null default now(),
  foreign key (member_id, gym_id) references public.members (id, gym_id) on delete restrict,
  unique (gym_id, member_id, business_date) -- one check-in per member per business day
);
create index attendance_member_idx on public.attendance_records (member_id, gym_id);

create function private.attendance_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.checked_in_at := now();
  new.business_date := private.gym_business_date(new.gym_id, new.checked_in_at);
  if (select auth.uid()) is not null then
    new.recorded_by := (select auth.uid());
  end if;
  return new;
end;
$$;

create trigger attendance_before_insert
  before insert on public.attendance_records
  for each row execute function private.attendance_before_insert();

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete restrict,
  actor_id uuid, -- auth user id (null for service/SQL); no FK, same reason as recorded_by
  action text not null check (action in ('insert', 'update', 'delete')),
  table_name text not null,
  record_id uuid not null,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_gym_created_idx on public.audit_logs (gym_id, created_at desc);
create index audit_logs_record_idx on public.audit_logs (gym_id, table_name, record_id);

create trigger audit_logs_append_only
  before update or delete on public.audit_logs
  for each row execute function private.reject_mutation();

create trigger audit_logs_no_truncate
  before truncate on public.audit_logs
  for each statement execute function private.reject_mutation();

-- Row-level audit trail, written by trigger only (clients have no INSERT on audit_logs).
create function private.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_row jsonb;
  v_gym uuid;
begin
  if tg_op = 'INSERT' then
    v_new := to_jsonb(new);
    v_row := v_new;
  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
    v_row := v_new;
  else
    v_old := to_jsonb(old);
    v_row := v_old;
  end if;

  v_gym := case when tg_table_name = 'gyms' then (v_row ->> 'id')::uuid
                else (v_row ->> 'gym_id')::uuid end;

  insert into public.audit_logs (gym_id, actor_id, action, table_name, record_id, old_data, new_data)
  values (v_gym, (select auth.uid()), lower(tg_op), tg_table_name, (v_row ->> 'id')::uuid, v_old, v_new);

  return null;
end;
$$;
