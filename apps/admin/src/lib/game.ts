/**
 * Pure game helpers shared by the admin UI. No React, no Supabase, no I/O,
 * so everything here is unit-testable with vitest.
 */

import { MAX_SPRITE_BYTES } from "./constants";

export const RARITIES = ["COMMON", "RARE", "EPIC", "LEGENDARY"] as const;
export type Rarity = (typeof RARITIES)[number];

/** Default base capture rate per rarity (CONTRACTS §1). Editable per professor. */
export const DEFAULT_CAPTURE_RATE: Record<Rarity, number> = {
  COMMON: 0.8,
  RARE: 0.6,
  EPIC: 0.4,
  LEGENDARY: 0.25,
};

/** Spanish labels shown next to the rarity color (label + color, never color alone). */
export const RARITY_LABELS: Record<Rarity, string> = {
  COMMON: "Común",
  RARE: "Rara",
  EPIC: "Épica",
  LEGENDARY: "Legendaria",
};

export function isRarity(value: unknown): value is Rarity {
  return typeof value === "string" && (RARITIES as readonly string[]).includes(value);
}

/** Shape of a professor as written to `public.professors` (without id/timestamps). */
export interface ProfessorInput {
  name: string;
  display_name: string;
  description: string | null;
  rarity: Rarity;
  base_capture_rate: number;
  sprite_url: string | null;
  active: boolean;
}

export type ProfessorField = keyof ProfessorInput;
export type ProfessorErrors = Partial<Record<ProfessorField, string>>;

export type ValidationResult =
  | { ok: true; value: ProfessorInput }
  | { ok: false; errors: ProfessorErrors };

export const MAX_NAME_LENGTH = 80;
export const MAX_DESCRIPTION_LENGTH = 500;

function asTrimmedString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asBoolean(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    return ["true", "on", "1", "yes"].includes(value.trim().toLowerCase());
  }
  return false;
}

/**
 * Parses a capture rate from a number or a string ("0.8", "0,8", ".5", "1").
 * Returns null when the value is not a finite number. Range is NOT checked here.
 */
export function parseRate(value: unknown): number | null {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value !== "string") return null;
  const normalized = value.trim().replace(",", ".");
  if (!/^-?(\d+\.?\d*|\.\d+)$/.test(normalized)) return null;
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * Validates raw form input (strings from FormData or already-typed values) and
 * returns either a normalized ProfessorInput or a map of Spanish error messages.
 */
export function validateProfessorInput(raw: Record<string, unknown>): ValidationResult {
  const errors: ProfessorErrors = {};

  const name = asTrimmedString(raw.name);
  const displayName = asTrimmedString(raw.display_name);
  const description = asTrimmedString(raw.description);
  const rarity = asTrimmedString(raw.rarity).toUpperCase();
  const spriteUrl = asTrimmedString(raw.sprite_url);
  const rate = parseRate(raw.base_capture_rate);

  if (!name) {
    errors.name = "El nombre es obligatorio.";
  } else if (name.length > MAX_NAME_LENGTH) {
    errors.name = `El nombre no puede superar ${MAX_NAME_LENGTH} caracteres.`;
  }

  if (!displayName) {
    errors.display_name = "El nombre visible es obligatorio.";
  } else if (displayName.length > MAX_NAME_LENGTH) {
    errors.display_name = `El nombre visible no puede superar ${MAX_NAME_LENGTH} caracteres.`;
  }

  if (description.length > MAX_DESCRIPTION_LENGTH) {
    errors.description = `La descripción no puede superar ${MAX_DESCRIPTION_LENGTH} caracteres.`;
  }

  if (!isRarity(rarity)) {
    errors.rarity = "Selecciona una rareza válida.";
  }

  if (rate === null) {
    errors.base_capture_rate = "La probabilidad de captura debe ser un número.";
  } else if (rate < 0 || rate > 1) {
    errors.base_capture_rate = "La probabilidad de captura debe estar entre 0 y 1.";
  }

  if (spriteUrl && !/^https?:\/\/\S+$/i.test(spriteUrl)) {
    errors.sprite_url = "La URL del sprite no es válida.";
  } else if (spriteUrl && isSvgUrl(spriteUrl)) {
    // Defence in depth: the uploader never produces an SVG, but the field is a
    // plain form value and the bucket is public (stored-XSS vector).
    errors.sprite_url = `No se admiten sprites SVG. Usa ${SPRITE_FORMATS_LABEL}.`;
  }

  if (Object.keys(errors).length > 0) {
    return { ok: false, errors };
  }

  return {
    ok: true,
    value: {
      name,
      display_name: displayName,
      description: description || null,
      rarity: rarity as Rarity,
      base_capture_rate: rate as number,
      sprite_url: spriteUrl || null,
      active: asBoolean(raw.active),
    },
  };
}

/** Formats a 0..1 rate as a Spanish percentage: 0.8 → "80 %", 0.255 → "25,5 %". */
export function formatRate(rate: number): string {
  if (!Number.isFinite(rate)) return "—";
  const percent = Math.round(rate * 1000) / 10;
  return `${percent.toString().replace(".", ",")} %`;
}

export interface AdminStats {
  total_players: number;
  total_captures: number;
  active_professors: number;
  completed_collections: number;
}

/**
 * Raster formats an admin may upload as a sprite. SVG is deliberately excluded:
 * the `professor-sprites` bucket is public and served from the Supabase origin,
 * so a stored SVG is a stored-XSS vector (it can carry <script>).
 */
export const SPRITE_MIME_TYPES = ["image/png", "image/jpeg", "image/webp", "image/gif"] as const;
export type SpriteMimeType = (typeof SPRITE_MIME_TYPES)[number];

/** Extensions accepted for each allowed MIME type; the first one is the canonical one. */
const SPRITE_EXTENSIONS_BY_MIME: Record<SpriteMimeType, readonly string[]> = {
  "image/png": ["png"],
  "image/jpeg": ["jpg", "jpeg"],
  "image/webp": ["webp"],
  "image/gif": ["gif"],
};

/** Value for the file input's `accept` attribute (types *and* extensions, no SVG). */
export const SPRITE_ACCEPT_ATTRIBUTE = [
  ...SPRITE_MIME_TYPES,
  ...SPRITE_MIME_TYPES.flatMap((mime) => SPRITE_EXTENSIONS_BY_MIME[mime].map((ext) => `.${ext}`)),
].join(",");

/** Human list of the allowed formats, for hints and error messages. */
export const SPRITE_FORMATS_LABEL = "PNG, JPG, WebP o GIF";

export function isSpriteMimeType(value: unknown): value is SpriteMimeType {
  return typeof value === "string" && (SPRITE_MIME_TYPES as readonly string[]).includes(value);
}

/** Lowercases a MIME type and drops any parameter: `image/PNG; charset=x` → `image/png`. */
export function normalizeMimeType(value: unknown): string {
  return typeof value === "string" ? value.split(";")[0].trim().toLowerCase() : "";
}

/** Extension of a file name, or "" when it has none that looks like one. */
export function fileExtension(fileName: string): string {
  const parts = String(fileName ?? "").trim().toLowerCase().split(".");
  const candidate = parts.length > 1 ? parts[parts.length - 1] : "";
  return /^[a-z0-9]{1,5}$/.test(candidate) ? candidate : "";
}

/** True when a URL points at an SVG file (query string and hash ignored). */
export function isSvgUrl(url: string): boolean {
  const path = String(url ?? "").split(/[?#]/)[0];
  return fileExtension(path) === "svg";
}

/**
 * Picks the storage extension for an uploaded sprite: the file name's extension
 * when it matches the (already validated) MIME type, otherwise the canonical
 * extension for that type — a file called "sprite" must not be stored as
 * `<uuid>.sprite`, and `evil.svg` must not keep a `.svg` name.
 */
export function spriteExtension(fileName: string, mimeType: string): string {
  const mime = normalizeMimeType(mimeType);
  const allowed = isSpriteMimeType(mime) ? SPRITE_EXTENSIONS_BY_MIME[mime] : [];
  const fromName = fileExtension(fileName);
  if (fromName && allowed.includes(fromName)) return fromName;
  return allowed[0] ?? "png";
}

/** Formats a byte cap for a message: 2097152 → "2 MB". */
export function formatMaxBytes(bytes: number): string {
  const megabytes = Math.round((bytes / (1024 * 1024)) * 10) / 10;
  return `${megabytes.toString().replace(".", ",")} MB`;
}

/** The parts of a `File` the sprite validation needs (so it stays testable in node). */
export interface SpriteFileMeta {
  name: string;
  type: string;
  size: number;
}

export type SpriteValidation =
  | { ok: true; contentType: SpriteMimeType; extension: string }
  | { ok: false; message: string };

/**
 * Validates a sprite before uploading it: real MIME type against the raster
 * allowlist, file-name extension against that same type (a spoofed `evil.svg`
 * labelled `image/png` is rejected), and the size cap. Returns the canonical
 * content type to send to Storage, so the object is never stored as
 * `image/svg+xml` even if the browser reports something else.
 *
 * Client-side only: it stops an honest mistake and the obvious abuse from the UI,
 * but it is not a security boundary (see apps/admin/README.md → Sprite uploads).
 */
export function validateSpriteFile(file: SpriteFileMeta, maxBytes: number = MAX_SPRITE_BYTES): SpriteValidation {
  if (!Number.isFinite(file.size) || file.size <= 0) {
    return { ok: false, message: "El archivo está vacío." };
  }
  if (file.size > maxBytes) {
    return { ok: false, message: `El sprite no puede superar ${formatMaxBytes(maxBytes)}.` };
  }

  const mime = normalizeMimeType(file.type);
  if (!isSpriteMimeType(mime)) {
    const shown = mime ? `«${mime}»` : "desconocido";
    return {
      ok: false,
      message: `Formato no permitido (${shown}). Usa ${SPRITE_FORMATS_LABEL}; los archivos SVG no se admiten.`,
    };
  }

  const extension = fileExtension(file.name);
  if (!extension) {
    return {
      ok: false,
      message: `El archivo debe tener una extensión de imagen (${SPRITE_FORMATS_LABEL}).`,
    };
  }
  if (!SPRITE_EXTENSIONS_BY_MIME[mime].includes(extension)) {
    return {
      ok: false,
      message: `La extensión «.${extension}» no corresponde al tipo del archivo («${mime}»).`,
    };
  }

  return { ok: true, contentType: mime, extension };
}

/**
 * Normalizes the `admin_stats()` RPC result. PostgREST may return the jsonb
 * object directly or wrapped in a one-row array; missing values become 0.
 */
export function normalizeAdminStats(data: unknown): AdminStats {
  const row = (Array.isArray(data) ? data[0] : data) as Record<string, unknown> | null | undefined;
  const num = (key: keyof AdminStats): number => {
    const value = Number(row?.[key] ?? 0);
    return Number.isFinite(value) ? value : 0;
  };
  return {
    total_players: num("total_players"),
    total_captures: num("total_captures"),
    active_professors: num("active_professors"),
    completed_collections: num("completed_collections"),
  };
}
