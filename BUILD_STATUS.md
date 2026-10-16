# Build status

Multi-tenant Gym Management SaaS (Android-first, v1).

## Phases

- [x] Phase 1 — Foundation
- [ ] Phase 2 — Schema & RLS
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
- Bottom-tab shell with placeholder screens: Dashboard, Members, Attendance, Payments, Settings (Settings has Sign out).
- Dark-navy theme tokens + one accent (`constants/theme.ts`); 56dp minimum touch targets.
- Shared `Screen` (loading / error / empty states) and `Button` components.
- Sign-in form validated with Zod; Supabase client uses SecureStore for session storage.
- Env config: `.env.example` committed, `.env` git-ignored; only the anon key is used in the app.
- Tooling: ESLint 9 + Prettier, Jest (`jest-expo`) + React Native Testing Library.
- Supabase CLI initialised (`supabase/config.toml`, project_id `gym-saas`); no migrations yet (Phase 2).

## Verified in Phase 1 (run in a Linux sandbox)

- `npx prettier --check .` — pass
- `npm run lint` — pass (0 errors)
- `npm run typecheck` — pass
- `npm test` — pass (4 suites, 10 tests)
- `npx expo export --platform android` — Android bundle builds successfully

## Fixes made while verifying

- `react-test-renderer` pinned to `19.3.0` (was `^19.3.0`, which resolved to 19.3.1 and broke `npm install` against `react@19.3.0`).
- `eslint` changed from `^10` to `^9.39.5` — `eslint-config-expo` bundles `eslint-plugin-react` / `eslint-plugin-import`, which do not support ESLint 10 yet.
- `eslint-import-resolver-typescript` added as a direct devDependency so the `@/*` alias resolves in lint.
- `tsconfig.json` now sets `types: ["jest", "node"]` (TypeScript 6 no longer auto-includes `@types/*`).
- Removed the default Expo template screens and components (Themed, EditScreenInfo, modal, etc.).

## Unverified

- App launch on an Android emulator/device (only the production bundle build was verified, not runtime).
- Sign-in / sign-out against a real Supabase project or the local Supabase stack (needs Docker; not run).
- Auth-gate redirect behaviour at runtime (signed-out → sign-in, signed-in → tabs); no automated test covers it yet.
- `expo-symbols` tab icons on Android (names chosen from Material Symbols; not visually checked).
- `supabase start` (local stack) was not run.
