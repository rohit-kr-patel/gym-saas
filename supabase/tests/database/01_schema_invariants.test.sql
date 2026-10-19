-- Schema invariants: money type, constraints, same-gym FKs, append-only, reversals, business date, audit.
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

select plan(53);

-- ------------------------------------------------------------- structure
select has_table('public', 'gyms', 'table gyms exists');
select has_table('public', 'user_profiles', 'table user_profiles exists');
select has_table('public', 'user_gym_roles', 'table user_gym_roles exists');
select has_table('public', 'members', 'table members exists');
select has_table('public', 'membership_plans', 'table membership_plans exists');
select has_table('public', 'member_subscriptions', 'table member_subscriptions exists');
select has_table('public', 'payments', 'table payments exists');
select has_table('public', 'attendance_records', 'table attendance_records exists');
select has_table('public', 'audit_logs', 'table audit_logs exists');

select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0, 'RLS is enabled on every public table');

select col_type_is('public', 'membership_plans', 'price_paise', 'bigint', 'plan price is bigint paise');
select col_type_is('public', 'member_subscriptions', 'price_paise', 'bigint', 'subscription price is bigint paise');
select col_type_is('public', 'payments', 'amount_paise', 'bigint', 'payment amount is bigint paise');

-- ------------------------------------------------------ amount constraints
select throws_ok($$insert into public.membership_plans (gym_id, name, duration_days, price_paise) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'neg', 30, -1)$$, '23514', null, 'negative plan price rejected');
select lives_ok($$insert into public.membership_plans (gym_id, name, duration_days, price_paise) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'free', 30, 0)$$, 'zero plan price allowed');
select throws_ok($$insert into public.membership_plans (gym_id, name, duration_days, price_paise) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'zero days', 0, 100)$$, '23514', null, 'zero duration rejected');
select throws_ok($$insert into public.payments (gym_id, member_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 0, 'cash')$$, '23514', null, 'zero payment rejected');
select throws_ok($$insert into public.payments (gym_id, member_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', -5, 'cash')$$, '23514', null, 'negative payment rejected');
select throws_ok($$insert into public.member_subscriptions (gym_id, member_id, plan_id, start_date, end_date, price_paise) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', '2026-03-10', '2026-03-01', 100)$$, '23514', null, 'subscription ending before it starts is rejected');

-- ------------------------------------------------------ same-gym invariants
select throws_ok($$insert into public.member_subscriptions (gym_id, member_id, plan_id, start_date, end_date, price_paise) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', '2026-03-01', '2026-03-31', 100)$$, '23503', null, 'subscription cannot use a plan from another gym');
select throws_ok($$insert into public.member_subscriptions (gym_id, member_id, plan_id, start_date, end_date, price_paise) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', '2026-03-01', '2026-03-31', 100)$$, '23503', null, 'subscription cannot use a member from another gym');
select throws_ok($$insert into public.payments (gym_id, member_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-0000-0000-0000-000000000001', 100, 'cash')$$, '23503', null, 'payment cannot reference a member from another gym');
select throws_ok($$insert into public.payments (gym_id, member_id, subscription_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000003', 100, 'cash')$$, '23503', null, 'payment cannot reference a subscription from another gym');
select throws_ok($$insert into public.payments (gym_id, member_id, subscription_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000003', 100, 'cash')$$, '23503', null, 'payment subscription must belong to the same member');
select throws_ok($$insert into public.attendance_records (gym_id, member_id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-0000-0000-0000-000000000001')$$, '23503', null, 'attendance cannot reference a member from another gym');
select throws_ok($$insert into public.payments (gym_id, member_id, subscription_id, kind, reverses_payment_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', 'reversal', 'bbbbbbbb-0000-0000-0000-000000000004', 100, 'cash')$$, '23514', 'a reversal must reference an original payment row', 'reversal cannot reference a payment from another gym');

-- ------------------------------------------------------- gym_id immutable
select throws_ok($$update public.members set gym_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$, '23514', 'gym_id is immutable', 'gym_id cannot be changed');

-- ----------------------------------------------------------- append-only
select throws_ok($$update public.payments set amount_paise = 1 where id = 'aaaaaaaa-0000-0000-0000-000000000004'$$, '23000', 'payments is append-only: UPDATE is not allowed', 'payments cannot be updated (even by superuser)');
select throws_ok($$delete from public.payments where id = 'aaaaaaaa-0000-0000-0000-000000000004'$$, '23000', 'payments is append-only: DELETE is not allowed', 'payments cannot be deleted');
select throws_ok($$truncate public.payments cascade$$, '23000', 'payments is append-only: TRUNCATE is not allowed', 'payments cannot be truncated');
select throws_ok($$update public.audit_logs set action = 'delete'$$, '23000', 'audit_logs is append-only: UPDATE is not allowed', 'audit logs cannot be updated');
select throws_ok($$delete from public.audit_logs$$, '23000', 'audit_logs is append-only: DELETE is not allowed', 'audit logs cannot be deleted');

-- --------------------------------------------------------------- reversals
select throws_ok($$insert into public.payments (gym_id, member_id, subscription_id, reverses_payment_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000004', 100, 'cash')$$, '23514', null, 'a plain payment cannot carry reverses_payment_id');
select throws_ok($$insert into public.payments (gym_id, member_id, subscription_id, kind, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', 'reversal', 100, 'cash')$$, '23514', null, 'a reversal must reference a payment');
select lives_ok($$insert into public.payments (id, gym_id, member_id, subscription_id, kind, reverses_payment_id, amount_paise, method) values ('aaaaaaaa-0000-0000-0000-0000000000f1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', 'reversal', 'aaaaaaaa-0000-0000-0000-000000000004', 20000, 'cash')$$, 'partial reversal is accepted');
select throws_ok($$insert into public.payments (gym_id, member_id, subscription_id, kind, reverses_payment_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', 'reversal', 'aaaaaaaa-0000-0000-0000-000000000004', 40000, 'cash')$$, '23514', null, 'reversals cannot exceed the original payment');
select lives_ok($$insert into public.payments (gym_id, member_id, subscription_id, kind, reverses_payment_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', 'reversal', 'aaaaaaaa-0000-0000-0000-000000000004', 30000, 'cash')$$, 'remaining amount can be reversed');
select throws_ok($$insert into public.payments (gym_id, member_id, subscription_id, kind, reverses_payment_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', 'reversal', 'aaaaaaaa-0000-0000-0000-000000000004', 1, 'cash')$$, '23514', null, 'fully reversed payment cannot be reversed again');
select throws_ok($$insert into public.payments (gym_id, member_id, subscription_id, kind, reverses_payment_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', 'reversal', 'aaaaaaaa-0000-0000-0000-0000000000f1', 1, 'cash')$$, '23514', 'a reversal must reference an original payment row', 'a reversal cannot reverse another reversal');
select throws_ok($$insert into public.payments (gym_id, member_id, kind, reverses_payment_id, amount_paise, method) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-0000-0000-000000000006', 'reversal', 'aaaaaaaa-0000-0000-0000-000000000004', 1, 'cash')$$, '23514', 'a reversal must match the original payment member and subscription', 'a reversal must match the original member/subscription');

-- ------------------------------------------- business date from gym timezone
insert into public.gyms (id, name, timezone) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Kiritimati Gym', 'Pacific/Kiritimati'),   -- UTC+14
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Pago Pago Gym',  'Pacific/Pago_Pago');    -- UTC-11
insert into public.members (id, gym_id, full_name) values
  ('cccccccc-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'K member'),
  ('dddddddd-0000-0000-0000-000000000001', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'P member');
-- The client tries to dictate the date and time; the server ignores both.
insert into public.payments (id, gym_id, member_id, amount_paise, method, paid_at, business_date) values
  ('cccccccc-0000-0000-0000-000000000004', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'cccccccc-0000-0000-0000-000000000001', 100, 'cash', '2000-01-01', '2000-01-01'),
  ('dddddddd-0000-0000-0000-000000000004', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'dddddddd-0000-0000-0000-000000000001', 100, 'cash', '2000-01-01', '2000-01-01');
insert into public.attendance_records (id, gym_id, member_id) values
  ('cccccccc-0000-0000-0000-000000000005', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'cccccccc-0000-0000-0000-000000000001');

select is((select business_date from public.payments where id = 'cccccccc-0000-0000-0000-000000000004'),
          (now() at time zone 'Pacific/Kiritimati')::date, 'payment business_date follows the gym timezone (UTC+14)');
select is((select business_date from public.payments where id = 'dddddddd-0000-0000-0000-000000000004'),
          (now() at time zone 'Pacific/Pago_Pago')::date, 'payment business_date follows the gym timezone (UTC-11)');
select isnt((select business_date from public.payments where id = 'cccccccc-0000-0000-0000-000000000004'),
            (select business_date from public.payments where id = 'dddddddd-0000-0000-0000-000000000004'),
            'the same instant is a different business date in different gym timezones');
select is((select paid_at from public.payments where id = 'cccccccc-0000-0000-0000-000000000004'), now(), 'client-supplied paid_at is ignored');
select is((select business_date from public.attendance_records where id = 'cccccccc-0000-0000-0000-000000000005'),
          (now() at time zone 'Pacific/Kiritimati')::date, 'attendance business_date follows the gym timezone');
select is((select joined_on from public.members where id = 'cccccccc-0000-0000-0000-000000000001'),
          (now() at time zone 'Pacific/Kiritimati')::date, 'member joined_on defaults to the gym business date');
select throws_ok($$insert into public.attendance_records (gym_id, member_id) values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'cccccccc-0000-0000-0000-000000000001')$$, '23505', null, 'one check-in per member per business day');
select throws_ok($$insert into public.gyms (name, timezone) values ('Bad TZ', 'Mars/Olympus')$$, '22023', null, 'invalid timezone rejected on insert');
select throws_ok($$update public.gyms set timezone = 'Nowhere/Land' where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$, '22023', null, 'invalid timezone rejected on update');

-- --------------------------------------------------------------- audit trail
insert into public.members (id, gym_id, full_name) values ('aaaaaaaa-0000-0000-0000-000000000007', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Audit Probe');
update public.members set full_name = 'Audit Probe Renamed' where id = 'aaaaaaaa-0000-0000-0000-000000000007';
select is((select count(*)::int from public.audit_logs where table_name = 'members' and record_id = 'aaaaaaaa-0000-0000-0000-000000000007' and action = 'insert' and gym_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'), 1, 'member insert is audited');
select is((select old_data ->> 'full_name' from public.audit_logs where record_id = 'aaaaaaaa-0000-0000-0000-000000000007' and action = 'update'), 'Audit Probe', 'member update audit keeps the old value');
select is((select new_data ->> 'full_name' from public.audit_logs where record_id = 'aaaaaaaa-0000-0000-0000-000000000007' and action = 'update'), 'Audit Probe Renamed', 'member update audit keeps the new value');
select is((select count(*)::int from public.audit_logs where table_name = 'payments' and record_id = 'aaaaaaaa-0000-0000-0000-0000000000f1' and action = 'insert'), 1, 'payment/reversal insert is audited');

select * from finish();
rollback;
