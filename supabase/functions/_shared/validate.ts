/**
 * Request-body validators shared by the three Edge Functions.
 *
 * Every rejection is an `AppError("INVALID_INPUT")` → HTTP 400 `{ error, message }`
 * (CONTRACTS §4). The rules are documented in `supabase/functions/README.md`
 * ("Input validation"); keep both in sync.
 */
import { AppError } from "./errors.ts";
import { isThrowQuality, isUuid, type ThrowQuality } from "./types.ts";

/**
 * Maximum accepted length of `tag_identifier`, in characters, measured **after**
 * trimming. Real NDEF payloads / NTAG UIDs are far shorter (a 7-byte UID is 14 hex
 * chars, the seed tags are `DEMO-TAG-0N`), so 128 is generous while still bounding
 * what reaches the database and the logs.
 */
export const MAX_TAG_IDENTIFIER_LENGTH = 128;

/**
 * C0/C1 control characters. NUL in particular cannot be stored in a Postgres `text`
 * column, so without this check it would surface as a 500 instead of a 400.
 */
function hasControlChars(value: string): boolean {
  for (const char of value) {
    const code = char.charCodeAt(0);
    if (code <= 0x1f || (code >= 0x7f && code <= 0x9f)) return true;
  }
  return false;
}

/** `tag_identifier`: must be a non-empty string, trimmed, ≤ 128 chars, no control chars. */
export function parseTagIdentifier(raw: unknown, field = "tag_identifier"): string {
  if (typeof raw !== "string") {
    throw new AppError("INVALID_INPUT", `El campo ${field} es obligatorio y debe ser texto.`);
  }
  const value = raw.trim();
  if (value.length === 0) {
    throw new AppError("INVALID_INPUT", `El campo ${field} no puede estar vacío.`);
  }
  if (value.length > MAX_TAG_IDENTIFIER_LENGTH) {
    throw new AppError(
      "INVALID_INPUT",
      `El campo ${field} no puede superar ${MAX_TAG_IDENTIFIER_LENGTH} caracteres.`,
    );
  }
  if (hasControlChars(value)) {
    throw new AppError("INVALID_INPUT", `El campo ${field} contiene caracteres no permitidos.`);
  }
  return value;
}

/** Required UUID field: canonical 8-4-4-4-12 hex form, no surrounding whitespace. */
export function parseUuid(raw: unknown, field: string): string {
  if (!isUuid(raw)) {
    throw new AppError("INVALID_INPUT", `El campo ${field} debe ser un UUID válido.`);
  }
  return raw;
}

/** Optional UUID field: `null` and a missing key both mean "no value"; anything else must be a UUID. */
export function parseOptionalUuid(raw: unknown, field: string): string | null {
  if (raw === undefined || raw === null) return null;
  if (!isUuid(raw)) {
    throw new AppError("INVALID_INPUT", `El campo ${field} debe ser un UUID o null.`);
  }
  return raw;
}

/** `throw_quality`: exactly one of the CONTRACTS §1 values (case-sensitive). */
export function parseThrowQuality(raw: unknown, field = "throw_quality"): ThrowQuality {
  if (!isThrowQuality(raw)) {
    throw new AppError(
      "INVALID_INPUT",
      `El campo ${field} debe ser MISS, GOOD, GREAT o EXCELLENT.`,
    );
  }
  return raw;
}

/** Optional boolean field: only a missing key falls back; `null`/strings/numbers are rejected. */
export function parseOptionalBoolean(raw: unknown, field: string, fallback: boolean): boolean {
  if (raw === undefined) return fallback;
  if (typeof raw !== "boolean") {
    throw new AppError("INVALID_INPUT", `El campo ${field} debe ser true o false.`);
  }
  return raw;
}
