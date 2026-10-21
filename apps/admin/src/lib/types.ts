import type { Rarity } from "./game";

/** Row of `public.professors` (CONTRACTS §2). */
export interface Professor {
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
}

export type ProfessorOption = Pick<Professor, "id" | "name" | "display_name" | "active">;

/** Row of `public.nfc_tags` (CONTRACTS §2). */
export interface NfcTag {
  id: string;
  professor_id: string | null;
  tag_identifier: string;
  active: boolean;
  created_at: string;
}

/** nfc_tags row with the embedded professor (many-to-one, so an object or null). */
export interface NfcTagRow extends NfcTag {
  professor: Pick<Professor, "id" | "name" | "display_name"> | null;
}

/** State returned by the login server action. */
export interface LoginState {
  error?: string;
  /** Echoed back so the field keeps its value after a failed attempt. */
  email?: string;
}

/** State returned by the professor save server action. */
export interface ProfessorFormState {
  errors: Partial<Record<string, string>>;
  message?: string;
}

/** State returned by the NFC register server action. */
export interface NfcFormState {
  error?: string;
  success?: string;
  values?: { tag_identifier: string; professor_id: string; active: boolean };
}
