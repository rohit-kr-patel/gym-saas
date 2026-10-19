-- Cross-tenant isolation: read / insert / update / delete, plus role limits.
begin;
create extension if not exists pgtap with schema extensions;

-- Fixture (as superuser). Fixed ids keep the assertions readable.
--   gym A aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa   gym B bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
--   entity ids: <gym>-0000-0000-0000-00000000000N  N: 1 member, 2 plan, 3 subscription,
--                                                     4 payment, 5 attendance, 6 second member
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner.a@t.test'),
  ('11111111-1111-1111-1111-222222222222', 'staff.a@t.test'),
  ('22222222-2222-2222-2222-111111111111', 'owner.b@t.test'),
  ('33333333-3333-3333-3333-111111111111', 'outsider@t.test');

insert into public.gyms (id, name) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Gym A'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Test Gym B');

insert into public.user_profiles (id, full_name) values
  ('11111111-1111-1111-1111-111111111111', 'Owner A'),
  ('11111111-1111-1111-1111-222222222222', 'Staff A'),
  ('22222222-2222-2222-2222-111111111111', 'Owner B');

insert into public.user_gym_roles (gym_id, user_id, role) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-222222222222', 'staff'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-111111111111', 'owner');

insert into public.members (id, gym_id, full_name, phone) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Member A1', '8000000001'),
  ('aaaaaaaa-0000-0000-0000-000000000006', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Member A2', '8000000002'),
  ('bbbbbbbb-0000-0000-0000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Member B1', '8000000001');

insert into public.membership_plans (id, gym_id, name, duration_days, price_paise) values
  ('aaaaaaaa-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'T Plan A', 30, 100000),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'T Plan B', 30, 100000);

insert into public.member_subscriptions (id, gym_id, member_id, plan_id, start_date, end_date, price_paise) values
  ('aaaaaaaa-0000-0000-0000-000000000003', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', '2026-01-01', '2026-01-31', 100000),
  ('bbbbbbbb-0000-0000-0000-000000000003', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'bbbbbbbb-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', '2026-01-01', '2026-01-31', 100000);

insert into public.payments (id, gym_id, member_id, subscription_id, amount_paise, method) values
  ('aaaaaaaa-0000-0000-0000-000000000004', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', 50000, 'cash'),
  ('bbbbbbbb-0000-0000-0000-000000000004', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'bbbbbbbb-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000003', 50000, 'cash');

insert into public.attendance_records (id, gym_id, member_id) values
  ('aaaaaaaa-0000-0000-0000-000000000005', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001'),
  ('bbbbbbbb-0000-0000-0000-000000000005', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'bbbbbbbb-0000-0000-0000-000000000001');

select plan(55);

-- ============================================================ owner of gym A
set local "request.jwt.claims" to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
set local role authenticated;

-- READ: owner A sees only gym A
select is((select count(*)::int from public.gyms), 1, 'owner A reads only own gym');
select is((select count(*)::int from public.members), 2, 'owner A reads only own members (2 in gym A, 0 from gym B)');
select is((select count(*)::int from public.membership_plans), 1, 'owner A reads only own plans');
select is((select count(*)::int from public.member_subscriptions), 1, 'owner A reads only own subscriptions');
select is((select count(*)::int from public.payments), 1, 'owner A reads only own payments');
select is((select count(*)::int from public.attendance_records), 1, 'owner A reads only own attendance');
select is((select count(*)::int from public.user_gym_roles), 2, 'owner A reads roles of own gym only');
select is((select count(*)::int from public.user_profiles), 2, 'owner A reads profiles of gym co-members only');
select is((select count(*)::int from public.audit_logs where gym_id <> 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'), 0, 'owner A reads no audit rows of other gyms');
select ok((select count(*) from public.audit_logs where gym_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') > 0, 'owner A reads own audit rows');

-- INSERT into another tenant is rejected by RLS WITH CHECK
select throws_ok($$insert into public.members (gym_id, full_name) values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'x')$$, '42501', null, 'owner A cannot insert member into gym B');
select throws_ok($$insert into public.membership_plans (gym_id, name, duration_days, price_paise) values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'x', 30, 100)$$, '42501', null, 'owner A cannot insert plan into gym B');
select throws_ok($$insert into public.member_subscriptions (gym_id, member_id, plan_id, start_date, end_date, price_paise) values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'bbbbbbbb-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', '2026-02-01', '2026-02-28', 100)$$, '42501', null, 'owner A cannot insert subscription into gym B');
select throws_ok($$insert into public.payments (gym_id, member_id, amount_paise, method) values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'bbbbbbbb-0000-0000-0000-000000000001', 100, 'cash')$$, '42501', null, 'owner A cannot insert payment into gym B');
select throws_ok($$insert into public.attendance_records (gym_id, member_id) values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'bbbbbbbb-0000-0000-0000-000000000006')$$, '42501', null, 'owner A cannot insert attendance into gym B');

-- No client inserts into gyms / user_gym_roles / audit_logs, even for own tenant
select throws_ok($$insert into public.gyms (name) values ('Rogue Gym')$$, '42501', null, 'clients cannot insert gyms');
select throws_ok($$insert into public.user_gym_roles (gym_id, user_id, role) values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'owner')$$, '42501', null, 'owner A cannot grant self a role in gym B');
select throws_ok($$insert into public.user_gym_roles (gym_id, user_id, role) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-111111111111', 'staff')$$, '42501', null, 'even an owner cannot insert roles from the client');
select throws_ok($$insert into public.audit_logs (gym_id, action, table_name, record_id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'insert', 'members', gen_random_uuid())$$, '42501', null, 'clients cannot write audit logs');

-- UPDATE other tenant: no rows touched
select is_empty($$update public.members set full_name = 'hacked' where gym_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' returning 1$$, 'owner A cannot update gym B members');
select is_empty($$update public.membership_plans set price_paise = 1 where gym_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' returning 1$$, 'owner A cannot update gym B plans');
select is_empty($$update public.member_subscriptions set status = 'cancelled' where gym_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' returning 1$$, 'owner A cannot update gym B subscriptions');
select is_empty($$update public.gyms set name = 'hacked' where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' returning 1$$, 'owner A cannot update gym B');
select is_empty($$update public.user_profiles set full_name = 'hacked' where id = '22222222-2222-2222-2222-111111111111' returning 1$$, 'owner A cannot update owner B profile');
select throws_ok($$update public.members set gym_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$, '23514', 'gym_id is immutable', 'owner A cannot move own member into gym B (gym_id is immutable)');

-- DELETE other tenant: no rows touched
select is_empty($$delete from public.members where gym_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' returning 1$$, 'owner A cannot delete gym B members');
select is_empty($$delete from public.membership_plans where gym_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' returning 1$$, 'owner A cannot delete gym B plans');
select is_empty($$delete from public.member_subscriptions where gym_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' returning 1$$, 'owner A cannot delete gym B subscriptions');
select is_empty($$delete from public.attendance_records where gym_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' returning 1$$, 'owner A cannot delete gym B attendance');

-- Payments / audit are append-only for clients, even in own tenant
select throws_ok($$update public.payments set amount_paise = 1 where gym_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$, '42501', null, 'owner A cannot update payments');
select throws_ok($$delete from public.payments where gym_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$, '42501', null, 'owner A cannot delete payments');
select throws_ok($$update public.attendance_records set member_id = member_id where gym_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$, '42501', null, 'attendance rows cannot be updated');
select throws_ok($$delete from public.audit_logs where gym_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$, '42501', null, 'owner A cannot delete audit logs');

-- Positive control: owner A can still work inside gym A
select lives_ok($$insert into public.members (gym_id, full_name, phone) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'New A Member', '8000000009')$$, 'owner A can insert member into gym A');
select lives_ok($$update public.gyms set name = 'Test Gym A (renamed)' where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$, 'owner A can rename own gym');
select throws_ok($$update public.gyms set created_at = now() where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$, '42501', null, 'owner A cannot update gym columns beyond name/timezone');

-- ============================================================ staff of gym A
reset role;
set local "request.jwt.claims" to '{"sub":"11111111-1111-1111-1111-222222222222","role":"authenticated"}';
set local role authenticated;

select is((select count(*)::int from public.members where gym_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'), 3, 'staff A reads all gym A members (incl. the one owner A added)');
select is((select count(*)::int from public.members where gym_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'), 0, 'staff A reads no gym B members');
select is((select count(*)::int from public.audit_logs), 0, 'staff cannot read audit logs');
select is((select count(*)::int from public.user_gym_roles), 1, 'staff only sees own role row');
select lives_ok($$insert into public.members (gym_id, full_name, phone) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Staff Added', '8000000010')$$, 'staff can insert member');
select lives_ok($$insert into public.payments (gym_id, member_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 1000, 'upi')$$, 'staff can record payment');
select lives_ok($$insert into public.attendance_records (gym_id, member_id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000006')$$, 'staff can record attendance');
select throws_ok($$insert into public.membership_plans (gym_id, name, duration_days, price_paise) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Staff Plan', 30, 100)$$, '42501', null, 'staff cannot create plans');
select is_empty($$update public.membership_plans set price_paise = 1 where gym_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning 1$$, 'staff cannot edit plans');
select is_empty($$delete from public.members where gym_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning 1$$, 'staff cannot delete members');
select is_empty($$delete from public.attendance_records where gym_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning 1$$, 'staff cannot delete attendance');
select is_empty($$update public.gyms set name = 'staff rename' where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning 1$$, 'staff cannot edit gym settings');

-- ====================================================== authenticated, no gym
reset role;
set local "request.jwt.claims" to '{"sub":"33333333-3333-3333-3333-111111111111","role":"authenticated"}';
set local role authenticated;

select is((select count(*)::int from public.gyms), 0, 'user without a role sees no gyms');
select is((select count(*)::int from public.members), 0, 'user without a role sees no members');
select is((select count(*)::int from public.payments), 0, 'user without a role sees no payments');
select throws_ok($$insert into public.members (gym_id, full_name) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'x')$$, '42501', null, 'user without a role cannot insert into any gym');

-- ======================================================================== anon
reset role;
set local "request.jwt.claims" to '{"role":"anon"}';
set local role anon;

select throws_ok($$select count(*) from public.members$$, '42501', null, 'anon has no access to members');
select throws_ok($$select count(*) from public.gyms$$, '42501', null, 'anon has no access to gyms');
select throws_ok($$select count(*) from public.payments$$, '42501', null, 'anon has no access to payments');

reset role;
select * from finish();
rollback;
