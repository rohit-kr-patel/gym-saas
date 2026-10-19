-- Phase 2 / 3 of 6 — members, membership_plans, member_subscriptions.
-- Same-gym invariants use composite FKs: (child_id, gym_id) -> parent(id, gym_id).
-- Money is integer paise (bigint), never floats.

create table public.members (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete restrict,
  full_name text not null check (length(btrim(full_name)) between 1 and 200),
  phone text check (phone is null or length(btrim(phone)) between 5 and 20),
  email text check (email is null or position('@' in email) > 1),
  joined_on date not null, -- defaulted from the gym's business date by trigger
  status text not null default 'active' check (status in ('active', 'inactive')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, gym_id)
);
create unique index members_gym_phone_uq on public.members (gym_id, phone) where phone is not null;
create index members_gym_status_idx on public.members (gym_id, status);

create table public.membership_plans (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete restrict,
  name text not null check (length(btrim(name)) between 1 and 100),
  duration_days integer not null check (duration_days > 0),
  price_paise bigint not null check (price_paise >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, gym_id),
  unique (gym_id, name)
);

create table public.member_subscriptions (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete restrict,
  member_id uuid not null,
  plan_id uuid not null,
  start_date date not null, -- defaulted from the gym's business date by trigger
  end_date date not null,
  price_paise bigint not null check (price_paise >= 0), -- snapshot of plan price at purchase
  status text not null default 'active' check (status in ('active', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date),
  unique (id, gym_id),
  unique (id, gym_id, member_id),
  foreign key (member_id, gym_id) references public.members (id, gym_id) on delete restrict,
  foreign key (plan_id, gym_id) references public.membership_plans (id, gym_id) on delete restrict
);
create index member_subscriptions_member_idx on public.member_subscriptions (member_id, gym_id);
create index member_subscriptions_plan_idx on public.member_subscriptions (plan_id, gym_id);
create index member_subscriptions_gym_end_idx on public.member_subscriptions (gym_id, end_date);

-- Default joined_on / start_date from the gym's business date (not the device clock).
create function private.members_defaults()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.joined_on is null then
    new.joined_on := private.gym_business_date(new.gym_id, now());
  end if;
  return new;
end;
$$;

create trigger members_defaults
  before insert on public.members
  for each row execute function private.members_defaults();

create function private.subscriptions_defaults()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.start_date is null then
    new.start_date := private.gym_business_date(new.gym_id, now());
  end if;
  return new;
end;
$$;

create trigger subscriptions_defaults
  before insert on public.member_subscriptions
  for each row execute function private.subscriptions_defaults();
