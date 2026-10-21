import { type Db, unwrap } from "./db.ts";
import type { ThrowQuality } from "./types.ts";

export const DEFAULT_ENCOUNTER_EXPIRATION_SECONDS = 180;

/** Contract defaults for `app_settings.throw_bonus` (the SQL RPC reads the live values). */
export const DEFAULT_THROW_BONUS: Record<ThrowQuality, number> = {
  MISS: -1.0,
  GOOD: 0.0,
  GREAT: 0.10,
  EXCELLENT: 0.20,
};

export interface AppSettings {
  encounterExpirationSeconds: number;
}

/** Reads `app_settings.encounter_expiration_seconds`; falls back to 180 when missing or invalid. */
export async function loadAppSettings(db: Db): Promise<AppSettings> {
  const row = unwrap(
    await db
      .from<{ key: string; value: unknown }>("app_settings")
      .select("key, value")
      .eq("key", "encounter_expiration_seconds")
      .maybeSingle(),
    "app_settings.select",
  );
  const raw = row?.value;
  const seconds = typeof raw === "number" ? raw : typeof raw === "string" ? Number(raw) : NaN;
  const valid = Number.isFinite(seconds) && seconds > 0;
  return {
    encounterExpirationSeconds: valid ? Math.floor(seconds) : DEFAULT_ENCOUNTER_EXPIRATION_SECONDS,
  };
}
