#!/usr/bin/env bash
# Runs migrations + seed + pgTAP on a plain local PostgreSQL (no Docker).
# Fallback for machines where `supabase start` is unavailable. The canonical
# path is `npm run db:reset && npm run db:test` (Supabase CLI, Postgres 17).
#
# Needs: a running PostgreSQL, pgTAP installed, and a superuser connection
# via the usual PG* env vars (PGHOST, PGUSER, ...). Creates/drops DB gym_saas_test.
set -euo pipefail
cd "$(dirname "$0")/../.."

DB=gym_saas_test
psql -v ON_ERROR_STOP=1 -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
# Roles are cluster-wide; drop leftovers from earlier runs.
psql -q -d postgres -c "drop role if exists anon" -c "drop role if exists authenticated" -c "drop role if exists service_role" 2>/dev/null || true
psql -v ON_ERROR_STOP=1 -q -d postgres -c "alter database $DB set search_path = \"\$user\", public, extensions"

run() { psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$1"; }

echo "== stub =="; run supabase/scripts/stub-supabase.sql
echo "== migrations =="
for f in supabase/migrations/*.sql; do echo "  $f"; run "$f"; done
echo "== seed =="; run supabase/seed.sql
psql -v ON_ERROR_STOP=1 -q -d "$DB" <<'SQL'
do $$
begin
  if (select count(*) from public.gyms) <> 2 then raise exception 'seed: expected 2 gyms'; end if;
  if exists (select 1 from public.gyms g where not exists (select 1 from public.members m where m.gym_id = g.id)) then
    raise exception 'seed: every gym needs members'; end if;
  if (select count(*) from public.user_gym_roles where role = 'owner') <> 2 then raise exception 'seed: expected 2 owners'; end if;
end $$;
SQL
echo "  seed OK (2 gyms, owners, members)"
echo "== pgTAP =="
pg_prove -d "$DB" -v supabase/tests/database/*.test.sql
