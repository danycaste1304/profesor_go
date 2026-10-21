import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Db } from "./db.ts";

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

const authOptions = { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false };

/** Service-role client: bypasses RLS. Only ever used server-side inside Edge Functions. */
export function createServiceClient(): SupabaseClient {
  return createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: authOptions,
  });
}

/** Anon-key client acting as the calling user (RLS applies). `authHeader` is the full `Bearer …` value. */
export function createUserClient(authHeader: string): SupabaseClient {
  return createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_ANON_KEY"), {
    auth: authOptions,
    global: { headers: { Authorization: authHeader } },
  });
}

/**
 * Views the client through the small `Db` surface the functions use (see `db.ts`).
 * supabase-js's query-builder generics (the `select("…")` string parser) are too deep for TypeScript
 * to verify structurally ("type instantiation is excessively deep"), so the shape is asserted here.
 * Runtime methods used: from().select().eq().maybeSingle()/single(), insert()/upsert()/update()
 * (+ .eq()/.select()), rpc().
 */
export function asDb(client: SupabaseClient): Db {
  return client as unknown as Db;
}
