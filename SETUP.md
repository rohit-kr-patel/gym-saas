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

## Local Supabase (optional in Phase 1)

```bash
npm run supabase:start    # needs Docker; prints the local URL and anon key
npm run supabase:status
npm run supabase:stop
```

Schema and RLS migrations arrive in Phase 2 (`supabase/migrations`).

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
- `.cursor/rules/` — project and phase rules
