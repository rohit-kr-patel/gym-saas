-- Minimal stand-in for the Supabase pieces our schema depends on, so the
-- migrations + pgTAP suite can run on a plain Postgres (no Docker).
-- NOT a migration. Never applied to a real Supabase project.

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

create schema auth;
create schema extensions;
grant usage on schema auth, extensions, public to anon, authenticated, service_role;

create extension pgcrypto with schema extensions;
create extension pgtap with schema extensions;

create table auth.users (
  instance_id uuid,
  id uuid primary key,
  aud text,
  role text,
  email text,
  encrypted_password text,
  email_confirmed_at timestamptz,
  raw_app_meta_data jsonb,
  raw_user_meta_data jsonb,
  created_at timestamptz,
  updated_at timestamptz,
  confirmation_token text,
  recovery_token text,
  email_change text,
  email_change_token_new text
);

create table auth.identities (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  provider_id text not null,
  provider text not null,
  identity_data jsonb not null,
  last_sign_in_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
);

create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

create function auth.role() returns text language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;

grant execute on function auth.uid(), auth.role() to anon, authenticated, service_role;

-- Mirror Supabase's permissive defaults so our explicit REVOKEs are exercised.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
grant all on all tables in schema auth to service_role;
