# Build status

Multi-tenant Gym Management SaaS (Android-first, v1).

## Phases

- [x] Phase 1 — Foundation
- [x] Phase 2 — Schema & RLS — **built; waiting for owner review of policies + test output before Phase 3**
- [ ] Phase 3 — Auth
- [ ] Phase 4 — Members & UI kit
- [ ] Phase 5 — Plans & subscriptions
- [ ] Phase 6 — Payments
- [ ] Phase 7 — Attendance, dashboard & reports
- [ ] Phase 8 — Settings & hardening
- [ ] Phase 9 — Release

## Phase 1 — what exists

- Expo Router app, TypeScript strict, `@/*` path alias.
- Auth-gated route groups: `(auth)` (sign-in) when signed out, `(app)` when signed in, via `Stack.Protected`.
- Bottom-tab shell: Dashboard, Members, Attendance, Payments, Settings (Sign out in Settings).
- Dark-navy theme tokens + one accent (`constants/theme.ts`); 56dp touch targets; shared `Screen` and `Button`.
- Zod-validated sign-in; Supabase client with SecureStore session storage.
- `.env.example` committed, `.env` git-ignored; only the anon key is used in the app.
- ESLint 9 + Prettier, Jest (`jest-expo`) + React Native Testing Library.

## Phase 2 — what exists

Migrations in `supabase/migrations/` (applied in order):

1. `…090000_helpers` — `private` schema (not API-exposed), `set_updated_at`, `prevent_gym_id_change`, `reject_mutation`, `gym_business_date`.
2. `…090100_core_tables` — `gyms`, `user_profiles`, `user_gym_roles`.
3. `…090200_members_plans_subscriptions` — `members`, `membership_plans`, `member_subscriptions`.
4. `…090300_payments_attendance_audit` — `payments`, `attendance_records`, `audit_logs`, audit trigger function.
5. `…090400_triggers_rls_grants` — triggers, role helpers, RLS policies, grants.
6. `…090500_provision_gym` — `public.provision_gym` (service-role only).

Also: `supabase/seed.sql` (two demo gyms), `scripts/provision-gym.js` (one-time script, `npm run db:provision`), pgTAP suites in `supabase/tests/database/`, and a no-Docker harness `supabase/scripts/local-pg-test.sh` (`npm run db:test:local`).

### Invariants as built

- **Money:** `bigint` paise everywhere; plan/subscription prices `>= 0`; payment amounts `> 0` (a payment of 0 is meaningless; the sign comes from `kind`).
- **Same-gym:** composite FKs `(child_id, gym_id) → parent(id, gym_id)` on every relationship (member/plan on subscriptions; member/subscription/reversed payment on payments; member on attendance). A payment's subscription must also belong to the payment's member. `gym_id` is immutable (trigger).
- **Payments append-only:** UPDATE/DELETE/TRUNCATE rejected by trigger for every role (including service role and owner); no UPDATE/DELETE privilege or policy for clients. Corrections are `kind = 'reversal'` rows; a trigger enforces: references a `payment` row, same member/subscription, total reversals never exceed the original (advisory-locked against races).
- **Business date:** `payments.business_date`, `attendance_records.business_date`, and default `members.joined_on` / `member_subscriptions.start_date` come from the gym's timezone (default `Asia/Kolkata`) via trigger. `paid_at` / `checked_in_at` are forced to server `now()`; client-supplied values are ignored. One check-in per member per business date.
- **RLS:** enabled on all 9 tables. Every policy goes through `private.has_gym_role(gym_id, roles[])` (security definer), which reads `user_gym_roles` for `auth.uid()`; client-supplied `gym_id` is only ever checked against it.
- **No client writes** to `gyms` (insert/delete; owner may update name/timezone only), `user_gym_roles` (read only), `audit_logs` (owner read only, written by trigger). `anon` has zero table privileges.
- **Grants:** all default Supabase grants revoked, minimum re-granted; default privileges changed so future tables/functions are not auto-exposed to `anon`/`authenticated` (later phases must grant explicitly).
- **Roles:** `owner` (everything in own gym, plans, deletes, audit read) and `staff` (read; create/update members, subscriptions; record payments and attendance; no deletes, no plans, no gym settings).
- **Audit:** insert/update/delete on gyms, roles, members, plans, subscriptions, payments, attendance recorded with old/new JSON and `auth.uid()`.

## Verified (Linux sandbox, PostgreSQL 16.15 + pgTAP 1.3.2, Supabase `auth`/roles stubbed)

- Migrations 1–6 apply cleanly in order; seed loads (2 gyms, 2 owners, members, plans, subscriptions, payments incl. one reversal, attendance).
- pgTAP: **128 / 128 pass** — 53 invariants, 55 cross-tenant RLS (read/insert/update/delete as owner A, staff A, role-less user, anon), 20 `provision_gym`.
- Mutation check: 8 deliberately weakened variants (open `members_select`, unchecked insert, UPDATE granted on payments, append-only trigger dropped, client insert on `user_gym_roles`, `provision_gym` granted to `authenticated`, staff allowed to delete plans, RLS disabled on payments) were each caught by the suite.
- `npm run verify`: lint pass, typecheck pass, 5 Jest suites / 14 tests pass; `expo export --platform android` bundles.

## Unverified

- Supabase CLI path (`supabase db reset`, `supabase test db`) on the real local stack / Postgres 17 — needs Docker, not run. Tests ran on PG16 with a hand-written stub of `auth.users`, `auth.uid()` and the `anon`/`authenticated`/`service_role` roles; real-Supabase differences (e.g. extra `auth.users` NOT NULL columns, default grants) are not covered.
- Seed demo logins (`owner.a@demo.gym.test` etc., password in `seed.sql`, local dev only): rows are inserted straight into `auth.users`/`auth.identities`; GoTrue sign-in with them has not been tried.
- `scripts/provision-gym.js` against a real project: only argument/env validation is unit-tested; the admin `createUser` + `rpc('provision_gym')` path has not been executed.
- Phase 1 items still open: Android emulator/device launch, runtime auth-gate redirects, tab icons on Android.

## Notes / fixes made this phase

- The pushed Phase 1 commit still contained the original Expo template files (`app/(tabs)/*`, `app/modal.tsx`, `app/+html.tsx`, template components, `constants/Colors.ts`). They failed lint and `app/(tabs)/index.tsx` would have collided with the gated routes, so they were removed.
- Staff management (adding staff / changing roles) has no client path by design; it needs a service-side function in a later phase.
