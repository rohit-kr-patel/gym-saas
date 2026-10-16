import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

import { readEnv } from './env';

const secureStorage = {
  getItem: (key: string) => SecureStore.getItemAsync(key),
  setItem: (key: string, value: string) => SecureStore.setItemAsync(key, value),
  removeItem: (key: string) => SecureStore.deleteItemAsync(key),
};

let client: SupabaseClient | null | undefined;

/** Returns the Supabase client, or null when env vars are not configured. */
export function getSupabase(): SupabaseClient | null {
  if (client !== undefined) return client;
  const env = readEnv();
  if (!env) {
    client = null;
    return client;
  }
  client = createClient(env.supabaseUrl, env.supabaseAnonKey, {
    auth: {
      storage: Platform.OS === 'web' ? undefined : secureStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  });
  return client;
}
