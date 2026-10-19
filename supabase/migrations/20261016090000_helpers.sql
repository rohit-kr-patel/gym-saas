-- Phase 2 / 1 of 6 — shared helper functions.
-- `private` is not exposed through the Supabase API (only `public` is), so
-- these functions are never callable as RPC from the app.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

-- Maintains updated_at.
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- A row never moves between gyms.
create function private.prevent_gym_id_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.gym_id is distinct from old.gym_id then
    raise exception 'gym_id is immutable' using errcode = '23514';
  end if;
  return new;
end;
$$;

-- Append-only guard (UPDATE / DELETE / TRUNCATE). Applies to every role,
-- including service_role and the table owner.
create function private.reject_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% is append-only: % is not allowed', tg_table_name, tg_op
    using errcode = '23000';
end;
$$;

-- Business date = calendar date in the gym's own timezone. Never the device
-- clock, never the database server's timezone.
create function private.gym_business_date(p_gym_id uuid, p_at timestamptz)
returns date
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz text;
begin
  select g.timezone into v_tz from public.gyms g where g.id = p_gym_id;
  if v_tz is null then
    raise exception 'gym % does not exist', p_gym_id using errcode = '23503';
  end if;
  return (p_at at time zone v_tz)::date;
end;
$$;

revoke all on function private.gym_business_date(uuid, timestamptz) from public;
grant execute on function private.gym_business_date(uuid, timestamptz) to service_role;
