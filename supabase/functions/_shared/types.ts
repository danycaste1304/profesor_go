/** Shared enums, validators and row shapes (CONTRACTS §1, §2). */

export const ROLES = ["player", "admin"] as const;
export type Role = (typeof ROLES)[number];

export const RARITIES = ["COMMON", "RARE", "EPIC", "LEGENDARY"] as const;
export type Rarity = (typeof RARITIES)[number];

export const THROW_QUALITIES = ["MISS", "GOOD", "GREAT", "EXCELLENT"] as const;
export type ThrowQuality = (typeof THROW_QUALITIES)[number];

export const ENCOUNTER_STATUSES = ["ACTIVE", "SUCCESS", "FAILED", "EXPIRED"] as const;
export type EncounterStatus = (typeof ENCOUNTER_STATUSES)[number];

function oneOf<T extends string>(values: readonly T[], v: unknown): v is T {
  return typeof v === "string" && (values as readonly string[]).includes(v);
}

export function isRole(v: unknown): v is Role {
  return oneOf(ROLES, v);
}

export function isRarity(v: unknown): v is Rarity {
  return oneOf(RARITIES, v);
}

export function isThrowQuality(v: unknown): v is ThrowQuality {
  return oneOf(THROW_QUALITIES, v);
}

export function isEncounterStatus(v: unknown): v is EncounterStatus {
  return oneOf(ENCOUNTER_STATUSES, v);
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(v: unknown): v is string {
  return typeof v === "string" && UUID_RE.test(v);
}

export function isNonEmptyString(v: unknown): v is string {
  return typeof v === "string" && v.trim().length > 0;
}

// Row shapes are type aliases (not interfaces) so they stay assignable to Record<string, unknown>.

export type ProfileRow = {
  id: string;
  email: string;
  display_name: string | null;
  role: Role;
  created_at: string;
  collection_completed_at: string | null;
};

export type ProfessorRow = {
  id: string;
  name: string;
  display_name: string;
  description: string | null;
  rarity: Rarity;
  sprite_url: string | null;
  active: boolean;
  base_capture_rate: number;
  created_at: string;
  updated_at: string;
};

export type NfcTagRow = {
  id: string;
  professor_id: string | null;
  tag_identifier: string;
  active: boolean;
  created_at: string;
};

export type EncounterRow = {
  id: string;
  user_id: string;
  professor_id: string;
  created_at: string;
  expires_at: string;
  status: EncounterStatus;
};

export type CaptureRow = {
  id: string;
  user_id: string;
  professor_id: string;
  encounter_id: string | null;
  throw_quality: ThrowQuality;
  captured_at: string;
};

export type CollectionProgress = {
  captured: number;
  total: number;
  completed: boolean;
};
