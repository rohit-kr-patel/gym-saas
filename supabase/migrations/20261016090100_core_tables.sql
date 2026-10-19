-- Phase 2 / 2 of 6 — gyms, user_profiles, user_gym_roles.

create table public.gyms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 200),
  timezone text not null default 'Asia/Kolkata',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function private.validate_gym_timezone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.timezone) then
    raise exception 'invalid timezone: %', new.timezone using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger gyms_validate_timezone
  before insert or update of timezone on public.gyms
  for each row execute function private.validate_gym_timezone();

-- Profile is gym-agnostic: one row per auth user.
create table public.user_profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text check (full_name is null or length(btrim(full_name)) between 1 and 200),
  phone text check (phone is null or length(btrim(phone)) between 5 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Role grants. Only written by provision_gym / service role — never by clients.
create table public.user_gym_roles (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete restrict,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'staff')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (gym_id, user_id)
);
create index user_gym_roles_user_id_idx on public.user_gym_roles (user_id);
