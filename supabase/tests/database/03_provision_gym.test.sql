-- provision_gym: service-role only, creates gym + owner role + profile.
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

select plan(20);

select ok(has_function_privilege('service_role', 'public.provision_gym(text,text,text,text)', 'execute'), 'service_role can execute provision_gym');
select ok(not has_function_privilege('authenticated', 'public.provision_gym(text,text,text,text)', 'execute'), 'authenticated cannot execute provision_gym');
select ok(not has_function_privilege('anon', 'public.provision_gym(text,text,text,text)', 'execute'), 'anon cannot execute provision_gym');

insert into auth.users (id, email) values ('44444444-4444-4444-4444-111111111111', 'New.Owner@T.test');

select lives_ok($$select public.provision_gym('Prov Gym One', 'new.owner@t.test')$$, 'provision_gym succeeds for an existing auth user (email case-insensitive)');
select is((select timezone from public.gyms where name = 'Prov Gym One'), 'Asia/Kolkata', 'timezone defaults to Asia/Kolkata');
select is((select r.role from public.user_gym_roles r join public.gyms g on g.id = r.gym_id
            where g.name = 'Prov Gym One' and r.user_id = '44444444-4444-4444-4444-111111111111'), 'owner', 'user becomes owner of the new gym');
select is((select count(*)::int from public.user_profiles where id = '44444444-4444-4444-4444-111111111111'), 1, 'owner profile row exists');

select lives_ok($$select public.provision_gym('Prov Gym Two', 'new.owner@t.test', 'Asia/Dubai', 'Nina Owner')$$, 'explicit timezone and name accepted');
select is((select timezone from public.gyms where name = 'Prov Gym Two'), 'Asia/Dubai', 'explicit timezone stored');
select is((select full_name from public.user_profiles where id = '44444444-4444-4444-4444-111111111111'), 'Nina Owner', 'owner full name stored on profile');

select throws_ok($$select public.provision_gym('Ghost Gym', 'nobody@t.test')$$, 'P0002', null, 'unknown owner email rejected');
select throws_ok($$select public.provision_gym('Bad TZ Gym', 'new.owner@t.test', 'Mars/Olympus')$$, '22023', null, 'invalid timezone rejected');
select throws_ok($$select public.provision_gym('   ', 'new.owner@t.test')$$, '23514', null, 'blank gym name rejected');
select is((select count(*)::int from public.gyms where name in ('Ghost Gym', 'Bad TZ Gym')), 0, 'failed provisioning leaves no gym behind');

-- JWT claim guard (defence in depth) for callers that somehow have EXECUTE
set local "request.jwt.claims" to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select throws_ok($$select public.provision_gym('Claim Gym', 'new.owner@t.test')$$, '42501', 'provision_gym is service-role only', 'authenticated JWT claim is refused inside the function');

-- Real roles
set local role authenticated;
select throws_ok($$select public.provision_gym('Client Gym', 'new.owner@t.test')$$, '42501', null, 'authenticated role is denied EXECUTE');
reset role;
set local "request.jwt.claims" to '{"role":"anon"}';
set local role anon;
select throws_ok($$select public.provision_gym('Anon Gym', 'new.owner@t.test')$$, '42501', null, 'anon role is denied EXECUTE');
reset role;

-- service_role can call it
set local "request.jwt.claims" to '{"role":"service_role"}';
set local role service_role;
select lives_ok($$select public.provision_gym('Service Gym', 'new.owner@t.test')$$, 'service_role can provision');
reset role;

-- The newly provisioned owner can see their gym through RLS
set local "request.jwt.claims" to '{"sub":"44444444-4444-4444-4444-111111111111","role":"authenticated"}';
set local role authenticated;
select is((select count(*)::int from public.gyms where name like 'Prov Gym%'), 2, 'provisioned owner sees their gyms');
select is((select count(*)::int from public.gyms where name = 'Test Gym A'), 0, 'provisioned owner does not see other gyms');
reset role;

select * from finish();
rollback;
