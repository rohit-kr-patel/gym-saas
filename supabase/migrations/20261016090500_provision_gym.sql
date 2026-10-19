-- Phase 2 / 6 of 6 — provision_gym (service-role only).
-- Clients cannot insert into gyms / user_gym_roles; this is the only way a gym is created.

create function public.provision_gym(
  p_name text,
  p_owner_email text,
  p_timezone text default 'Asia/Kolkata',
  p_owner_full_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claims_role text;
  v_user_id uuid;
  v_gym_id uuid;
begin
  -- Defence in depth: EXECUTE is already revoked from anon/authenticated.
  v_claims_role := coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '');
  if v_claims_role in ('anon', 'authenticated') then
    raise exception 'provision_gym is service-role only' using errcode = '42501';
  end if;

  select u.id into v_user_id
    from auth.users u
    where lower(u.email) = lower(btrim(p_owner_email));
  if v_user_id is null then
    raise exception 'no auth user with email %: create the user first', p_owner_email
      using errcode = 'P0002';
  end if;

  insert into public.gyms (name, timezone)
    values (btrim(p_name), coalesce(p_timezone, 'Asia/Kolkata'))
    returning id into v_gym_id;

  insert into public.user_profiles (id, full_name)
    values (v_user_id, nullif(btrim(p_owner_full_name), ''))
    on conflict (id) do update
      set full_name = coalesce(excluded.full_name, user_profiles.full_name);

  insert into public.user_gym_roles (gym_id, user_id, role)
    values (v_gym_id, v_user_id, 'owner');

  return v_gym_id;
end;
$$;

revoke all on function public.provision_gym(text, text, text, text) from public, anon, authenticated;
grant execute on function public.provision_gym(text, text, text, text) to service_role;
