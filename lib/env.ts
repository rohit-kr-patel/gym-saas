export type AppEnv = {
  supabaseUrl: string;
  supabaseAnonKey: string;
};

/**
 * Reads public Expo env vars. Only the anon key belongs in the app —
 * never the service-role key.
 */
export function readEnv(source: Record<string, string | undefined> = process.env): AppEnv | null {
  const supabaseUrl = source.EXPO_PUBLIC_SUPABASE_URL?.trim();
  const supabaseAnonKey = source.EXPO_PUBLIC_SUPABASE_ANON_KEY?.trim();
  if (!supabaseUrl || !supabaseAnonKey) return null;
  return { supabaseUrl, supabaseAnonKey };
}
