-- Local development seed: two demo gyms, so cross-tenant behaviour is visible.
-- LOCAL DEV ONLY. Contains a throwaway demo password. Never run against production.
-- Loaded automatically by `supabase db reset`.

do $seed$
declare
  c_owner_a constant uuid := 'd0000000-0000-0000-0000-0000000000a1';
  c_staff_a constant uuid := 'd0000000-0000-0000-0000-0000000000a2';
  c_owner_b constant uuid := 'd0000000-0000-0000-0000-0000000000b1';
  v_pw text := extensions.crypt('DemoPass123!', extensions.gen_salt('bf'));
  v_gym_a uuid;
  v_gym_b uuid;
  v_plan_a_month uuid;
  v_plan_a_quarter uuid;
  v_plan_b_month uuid;
  v_m1 uuid; v_m2 uuid; v_m3 uuid; v_m4 uuid; v_m5 uuid;
  v_s1 uuid; v_s2 uuid; v_s4 uuid;
  v_p1 uuid;
  v_today_a date;
  v_today_b date;
  r record;
begin
  -- Auth users (email/password login works locally).
  for r in
    select * from (values
      (c_owner_a, 'owner.a@demo.gym.test'),
      (c_staff_a, 'staff.a@demo.gym.test'),
      (c_owner_b, 'owner.b@demo.gym.test')
    ) as t(id, email)
  loop
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new
    ) values (
      '00000000-0000-0000-0000-000000000000', r.id, 'authenticated', 'authenticated',
      r.email, v_pw, now(),
      '{"provider":"email","providers":["email"]}', '{}', now(), now(),
      '', '', '', ''
    );
    insert into auth.identities (
      id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), r.id, r.id::text, 'email',
      jsonb_build_object('sub', r.id::text, 'email', r.email, 'email_verified', true),
      now(), now(), now()
    );
  end loop;

  v_gym_a := public.provision_gym('Iron Paradise Fitness', 'owner.a@demo.gym.test', 'Asia/Kolkata', 'Asha Verma');
  v_gym_b := public.provision_gym('Pulse Fitness Studio', 'owner.b@demo.gym.test', 'Asia/Kolkata', 'Bharat Singh');

  -- Staff for gym A.
  insert into public.user_profiles (id, full_name) values (c_staff_a, 'Sunita Rao');
  insert into public.user_gym_roles (gym_id, user_id, role) values (v_gym_a, c_staff_a, 'staff');

  v_today_a := private.gym_business_date(v_gym_a, now());
  v_today_b := private.gym_business_date(v_gym_b, now());

  -- ---------------------------------------------------------------- gym A
  insert into public.membership_plans (gym_id, name, duration_days, price_paise)
    values (v_gym_a, 'Monthly', 30, 100000) returning id into v_plan_a_month;
  insert into public.membership_plans (gym_id, name, duration_days, price_paise)
    values (v_gym_a, 'Quarterly', 90, 270000) returning id into v_plan_a_quarter;
  insert into public.membership_plans (gym_id, name, duration_days, price_paise)
    values (v_gym_a, 'Annual', 365, 900000);

  insert into public.members (gym_id, full_name, phone) values (v_gym_a, 'Rahul Sharma', '9000000001') returning id into v_m1;
  insert into public.members (gym_id, full_name, phone) values (v_gym_a, 'Priya Patel',  '9000000002') returning id into v_m2;
  insert into public.members (gym_id, full_name, phone) values (v_gym_a, 'Amit Kumar',   '9000000003') returning id into v_m3;

  insert into public.member_subscriptions (gym_id, member_id, plan_id, start_date, end_date, price_paise)
    values (v_gym_a, v_m1, v_plan_a_month, v_today_a, v_today_a + 30, 100000) returning id into v_s1;
  insert into public.member_subscriptions (gym_id, member_id, plan_id, start_date, end_date, price_paise)
    values (v_gym_a, v_m2, v_plan_a_quarter, v_today_a, v_today_a + 90, 270000) returning id into v_s2;

  insert into public.payments (gym_id, member_id, subscription_id, amount_paise, method, reference)
    values (v_gym_a, v_m1, v_s1, 100000, 'upi', 'UPI-DEMO-0001') returning id into v_p1;
  insert into public.payments (gym_id, member_id, subscription_id, amount_paise, method)
    values (v_gym_a, v_m2, v_s2, 270000, 'cash');
  -- A correction is a reversal row, never an update/delete.
  insert into public.payments (gym_id, member_id, subscription_id, kind, reverses_payment_id, amount_paise, method, note)
    values (v_gym_a, v_m1, v_s1, 'reversal', v_p1, 100000, 'upi', 'Demo: duplicate entry');

  insert into public.attendance_records (gym_id, member_id) values (v_gym_a, v_m1), (v_gym_a, v_m2);

  -- ---------------------------------------------------------------- gym B
  insert into public.membership_plans (gym_id, name, duration_days, price_paise)
    values (v_gym_b, 'Monthly', 30, 120000) returning id into v_plan_b_month;
  insert into public.membership_plans (gym_id, name, duration_days, price_paise)
    values (v_gym_b, 'Annual', 365, 1000000);

  insert into public.members (gym_id, full_name, phone) values (v_gym_b, 'Neha Gupta',  '9000000001') returning id into v_m4;
  insert into public.members (gym_id, full_name, phone) values (v_gym_b, 'Vikram Joshi', '9000000004') returning id into v_m5;

  insert into public.member_subscriptions (gym_id, member_id, plan_id, start_date, end_date, price_paise)
    values (v_gym_b, v_m4, v_plan_b_month, v_today_b, v_today_b + 30, 120000) returning id into v_s4;
  insert into public.payments (gym_id, member_id, subscription_id, amount_paise, method)
    values (v_gym_b, v_m4, v_s4, 120000, 'card');
  insert into public.attendance_records (gym_id, member_id) values (v_gym_b, v_m4);
end;
$seed$;
