# Setup

## Prerequisites

- Node.js 20+ and npm
- Android Studio emulator or an Android device with Expo Go / a dev build
- Docker (only for the local Supabase stack)

## Install

```bash
npm install
cp .env.example .env
```

Fill in `.env`:

- `EXPO_PUBLIC_SUPABASE_URL` — `http://127.0.0.1:54321` for local, or your project URL
- `EXPO_PUBLIC_SUPABASE_ANON_KEY` — the **anon** key only

Never put the service-role key in the app or in Git. `.env` is git-ignored.

## Run

```bash
npm run android   # start Metro and open on Android
npm start         # start Metro, choose a target
```

Without env vars the app still starts and shows a "not configured" notice on the sign-in screen.

## Local Supabase

```bash
npm run supabase:start    # needs Docker; prints the local URL and anon key
npm run db:reset          # applies supabase/migrations + supabase/seed.sql
npm run db:test           # pgTAP suites in supabase/tests/database (supabase test db)
npm run supabase:stop
```

No Docker? Run the same migrations, seed and pgTAP suites on a plain local PostgreSQL
with pgTAP installed (uses a small stub of Supabase's `auth` schema and roles):

```bash
# needs PG* env vars for a superuser connection; creates/drops database gym_saas_test
npm run db:test:local
```

### Seed data (local only)

`supabase/seed.sql` creates two demo gyms. Demo logins (throwaway password in the seed file,
never use outside local dev): `owner.a@demo.gym.test`, `staff.a@demo.gym.test`, `owner.b@demo.gym.test`.

### Provisioning a real gym (one time)

Gyms and owner roles can only be created by the service-role-only `provision_gym` function.
Run from your machine; the service-role key comes from the shell, never from `.env` or Git:

```bash
SUPABASE_URL=https://<project>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<service-role-key> \
  npm run db:provision -- --name "My Gym" --email owner@example.com [--timezone Asia/Kolkata] [--full-name "Owner Name"]
```

If the owner has no auth user yet, one is created and a temporary password is printed once.

## Checks

```bash
npm run lint
npm run typecheck
npm test
npm run verify    # all three
npm run format    # Prettier
```

## Project layout

- `app/(auth)` — signed-out routes (sign-in)
- `app/(app)/(tabs)` — signed-in tab shell
- `components/`, `constants/theme.ts`, `lib/`, `providers/`
- `__tests__/` — Jest + React Native Testing Library
- `supabase/migrations`, `supabase/seed.sql`, `supabase/tests/database` — schema, RLS, seed, pgTAP
- `scripts/provision-gym.js` — one-time gym provisioning
- `.cursor/rules/` — project and phase rules
