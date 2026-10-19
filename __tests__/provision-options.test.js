/* global describe, it, expect */
const { readOptions, DEFAULT_TIMEZONE } = require('../scripts/provision-gym');

const env = { SUPABASE_URL: 'http://127.0.0.1:54321', SUPABASE_SERVICE_ROLE_KEY: 'service-key' };

describe('provision-gym readOptions', () => {
  it('parses a minimal valid invocation and applies the default timezone', () => {
    const r = readOptions(['--name', ' Iron Paradise ', '--email', 'Owner@Example.com'], env);
    expect(r.ok).toBe(true);
    expect(r.options).toMatchObject({
      name: 'Iron Paradise',
      email: 'owner@example.com',
      timezone: DEFAULT_TIMEZONE,
      fullName: null,
      password: null,
    });
  });

  it('accepts optional flags', () => {
    const r = readOptions(
      [
        '--name',
        'G',
        '--email',
        'a@b.co',
        '--timezone',
        'Asia/Dubai',
        '--full-name',
        'Asha',
        '--password',
        'longenough',
      ],
      env,
    );
    expect(r.ok).toBe(true);
    expect(r.options).toMatchObject({
      timezone: 'Asia/Dubai',
      fullName: 'Asha',
      password: 'longenough',
    });
  });

  it('reports every missing or invalid input', () => {
    const r = readOptions(['--email', 'nope', '--password', 'short'], {});
    expect(r.ok).toBe(false);
    expect(r.errors).toEqual(
      expect.arrayContaining([
        '--name is required',
        '--email is not a valid email',
        '--password must be at least 8 characters',
        'SUPABASE_URL env var is required',
        'SUPABASE_SERVICE_ROLE_KEY env var is required',
      ]),
    );
  });

  it('rejects unknown flags', () => {
    expect(() => readOptions(['--bogus', 'x'], env)).toThrow();
  });
});
