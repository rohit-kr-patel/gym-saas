import { readEnv } from '@/lib/env';

describe('readEnv', () => {
  it('returns null when vars are missing', () => {
    expect(readEnv({})).toBeNull();
    expect(readEnv({ EXPO_PUBLIC_SUPABASE_URL: 'http://x' })).toBeNull();
  });

  it('returns trimmed values when both are set', () => {
    expect(
      readEnv({ EXPO_PUBLIC_SUPABASE_URL: ' http://x ', EXPO_PUBLIC_SUPABASE_ANON_KEY: ' k ' }),
    ).toEqual({ supabaseUrl: 'http://x', supabaseAnonKey: 'k' });
  });
});
