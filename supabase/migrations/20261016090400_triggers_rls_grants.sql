-- Phase 2 / 5 of 6 — triggers, role helpers, RLS policies, grants.

-- ---------------------------------------------------------------- triggers
do $$
declare
  t text;
begin
  foreach t in array array[
    'gyms', 'user_profiles', 'user_gym_roles', 'members',
    'membership_plans', 'member_subscriptions'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function private.set_updated_at()',
      t || '_set_updated_at', t);
  end loop;

  foreach t in array array[
    'user_gym_roles', 'members', 'membership_plans', 'member_subscriptions',
    'payments', 'attendance_records'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function private.prevent_gym_id_change()',
      t || '_gym_id_immutable', t);
  end loop;

  foreach t in array array[
    'gyms', 'user_gym_roles', 'members', 'membership_plans',
    'member_subscriptions', 'payments', 'attendance_records'
  ] loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I for each row execute function private.audit_row_change()',
      t || '_audit', t);
  end loop;
end;
$$;

-- ----------------------------------------------------------- role helpers
-- The ONLY source of "which gym may this caller touch" is user_gym_roles for
-- auth.uid(). Client-supplied gym_id values are checked against it, never trusted.
create function private.has_gym_role(p_gym_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_gym_roles r
    where r.gym_id = p_gym_id
      and r.user_id = (select auth.uid())
      and r.role = any (p_roles)
  );
$$;

create function private.shares_gym_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_gym_roles me
    join public.user_gym_roles other on other.gym_id = me.gym_id
    where me.user_id = (select auth.uid())
      and other.user_id = p_user_id
  );
$$;

revoke all on function private.has_gym_role(uuid, text[]) from public;
revoke all on function private.shares_gym_with(uuid) from public;
grant execute on function private.has_gym_role(uuid, text[]) to authenticated, service_role;
grant execute on function private.shares_gym_with(uuid) to authenticated, service_role;

-- --------------------------------------------------------------------- RLS
alter table public.gyms enable row level security;
alter table public.user_profiles enable row level security;
alter table public.user_gym_roles enable row level security;
alter table public.members enable row level security;
alter table public.membership_plans enable row level security;
alter table public.member_subscriptions enable row level security;
alter table public.payments enable row level security;
alter table public.attendance_records enable row level security;
alter table public.audit_logs enable row level security;

-- gyms: members read; owner edits name/timezone. No client insert/delete.
create policy gyms_select on public.gyms for select to authenticated
  using (private.has_gym_role(id, array['owner', 'staff']));
create policy gyms_update_owner on public.gyms for update to authenticated
  using (private.has_gym_role(id, array['owner']))
  with check (private.has_gym_role(id, array['owner']));

-- user_profiles: own row, plus co-members of a shared gym (read only).
create policy user_profiles_select on public.user_profiles for select to authenticated
  using (id = (select auth.uid()) or private.shares_gym_with(id));
create policy user_profiles_update_self on public.user_profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- user_gym_roles: read only. Own rows; owners see every role in their gym.
create policy user_gym_roles_select on public.user_gym_roles for select to authenticated
  using (user_id = (select auth.uid()) or private.has_gym_role(gym_id, array['owner']));

-- members
create policy members_select on public.members for select to authenticated
  using (private.has_gym_role(gym_id, array['owner', 'staff']));
create policy members_insert on public.members for insert to authenticated
  with check (private.has_gym_role(gym_id, array['owner', 'staff']));
create policy members_update on public.members for update to authenticated
  using (private.has_gym_role(gym_id, array['owner', 'staff']))
  with check (private.has_gym_role(gym_id, array['owner', 'staff']));
create policy members_delete_owner on public.members for delete to authenticated
  using (private.has_gym_role(gym_id, array['owner']));

-- membership_plans: everyone reads, owner manages.
create policy membership_plans_select on public.membership_plans for select to authenticated
  using (private.has_gym_role(gym_id, array['owner', 'staff']));
create policy membership_plans_insert_owner on public.membership_plans for insert to authenticated
  with check (private.has_gym_role(gym_id, array['owner']));
create policy membership_plans_update_owner on public.membership_plans for update to authenticated
  using (private.has_gym_role(gym_id, array['owner']))
  with check (private.has_gym_role(gym_id, array['owner']));
create policy membership_plans_delete_owner on public.membership_plans for delete to authenticated
  using (private.has_gym_role(gym_id, array['owner']));

-- member_subscriptions
create policy member_subscriptions_select on public.member_subscriptions for select to authenticated
  using (private.has_gym_role(gym_id, array['owner', 'staff']));
create policy member_subscriptions_insert on public.member_subscriptions for insert to authenticated
  with check (private.has_gym_role(gym_id, array['owner', 'staff']));
create policy member_subscriptions_update on public.member_subscriptions for update to authenticated
  using (private.has_gym_role(gym_id, array['owner', 'staff']))
  with check (private.has_gym_role(gym_id, array['owner', 'staff']));
create policy member_subscriptions_delete_owner on public.member_subscriptions for delete to authenticated
  using (private.has_gym_role(gym_id, array['owner']));

-- payments: append-only. SELECT + INSERT only; no UPDATE/DELETE policy or privilege.
create policy payments_select on public.payments for select to authenticated
  using (private.has_gym_role(gym_id, array['owner', 'staff']));
create policy payments_insert on public.payments for insert to authenticated
  with check (private.has_gym_role(gym_id, array['owner', 'staff']));

-- attendance_records: no UPDATE; owner can delete mistaken check-ins.
create policy attendance_select on public.attendance_records for select to authenticated
  using (private.has_gym_role(gym_id, array['owner', 'staff']));
create policy attendance_insert on public.attendance_records for insert to authenticated
  with check (private.has_gym_role(gym_id, array['owner', 'staff']));
create policy attendance_delete_owner on public.attendance_records for delete to authenticated
  using (private.has_gym_role(gym_id, array['owner']));

-- audit_logs: owner read only; rows are written by trigger.
create policy audit_logs_select_owner on public.audit_logs for select to authenticated
  using (private.has_gym_role(gym_id, array['owner']));

-- ------------------------------------------------------------------ grants
-- Supabase grants ALL on new public tables to anon/authenticated by default.
-- Strip that, then grant the minimum. anon gets nothing.
revoke all on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

grant select on public.gyms to authenticated;
grant update (name, timezone) on public.gyms to authenticated;
grant select on public.user_profiles to authenticated;
grant update (full_name, phone) on public.user_profiles to authenticated;
grant select on public.user_gym_roles to authenticated;
grant select, insert, update, delete on public.members to authenticated;
grant select, insert, update, delete on public.membership_plans to authenticated;
grant select, insert, update, delete on public.member_subscriptions to authenticated;
grant select, insert on public.payments to authenticated;
grant select, insert, delete on public.attendance_records to authenticated;
grant select on public.audit_logs to authenticated;
