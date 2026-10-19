#!/usr/bin/env node
/**
 * One-time gym provisioning (service role). Run from your machine, never from the app.
 *
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
 *     npm run db:provision -- --name "Iron Paradise" --email owner@example.com [--timezone Asia/Kolkata] [--full-name "Asha"] [--password "..."]
 *
 * Creates the owner's auth user if needed (confirmed email), then calls the
 * service-role-only `provision_gym` SQL function. The service-role key is read
 * from the shell environment only — never from .env, never committed.
 */
const { randomBytes } = require('node:crypto');
const { parseArgs } = require('node:util');

const DEFAULT_TIMEZONE = 'Asia/Kolkata';

function readOptions(argv, env) {
  const { values } = parseArgs({
    args: argv,
    options: {
      name: { type: 'string' },
      email: { type: 'string' },
      timezone: { type: 'string' },
      'full-name': { type: 'string' },
      password: { type: 'string' },
    },
    strict: true,
  });

  const errors = [];
  const name = (values.name ?? '').trim();
  const email = (values.email ?? '').trim().toLowerCase();
  if (!name) errors.push('--name is required');
  if (!email) errors.push('--email is required');
  else if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) errors.push('--email is not a valid email');
  if (values.password !== undefined && values.password.length < 8) {
    errors.push('--password must be at least 8 characters');
  }

  const supabaseUrl = (env.SUPABASE_URL ?? '').trim();
  const serviceRoleKey = (env.SUPABASE_SERVICE_ROLE_KEY ?? '').trim();
  if (!supabaseUrl) errors.push('SUPABASE_URL env var is required');
  if (!serviceRoleKey) errors.push('SUPABASE_SERVICE_ROLE_KEY env var is required');

  if (errors.length > 0) return { ok: false, errors };
  return {
    ok: true,
    options: {
      name,
      email,
      timezone: (values.timezone ?? DEFAULT_TIMEZONE).trim(),
      fullName: values['full-name']?.trim() || null,
      password: values.password ?? null,
      supabaseUrl,
      serviceRoleKey,
    },
  };
}

async function main() {
  let parsed;
  try {
    parsed = readOptions(process.argv.slice(2), process.env);
  } catch (e) {
    console.error(`Error: ${e.message}`);
    process.exit(2);
  }
  if (!parsed.ok) {
    parsed.errors.forEach((e) => console.error(`Error: ${e}`));
    process.exit(2);
  }
  const o = parsed.options;

  const { createClient } = require('@supabase/supabase-js');
  const admin = createClient(o.supabaseUrl, o.serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let generatedPassword = null;
  const password = o.password ?? (generatedPassword = randomBytes(12).toString('base64url'));
  const created = await admin.auth.admin.createUser({
    email: o.email,
    password,
    email_confirm: true,
  });
  let userCreated = true;
  if (created.error) {
    const exists =
      created.error.code === 'email_exists' || /already.*registered/i.test(created.error.message);
    if (!exists) {
      console.error(`Could not create auth user: ${created.error.message}`);
      process.exit(1);
    }
    userCreated = false;
    generatedPassword = null;
  }

  const { data, error } = await admin.rpc('provision_gym', {
    p_name: o.name,
    p_owner_email: o.email,
    p_timezone: o.timezone,
    p_owner_full_name: o.fullName,
  });
  if (error) {
    console.error(`provision_gym failed: ${error.message}`);
    process.exit(1);
  }

  console.log(`Gym provisioned: ${data}`);
  console.log(`Owner: ${o.email} (${userCreated ? 'auth user created' : 'existing auth user'})`);
  if (generatedPassword) {
    console.log(`Temporary password (shown once): ${generatedPassword}`);
  }
}

module.exports = { readOptions, DEFAULT_TIMEZONE };

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
