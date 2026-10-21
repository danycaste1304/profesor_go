import { type AuthVerifier, getUserFromRequest } from "../_shared/auth.ts";
import { type Db, unwrap, unwrapRequired } from "../_shared/db.ts";
import { AppError, jsonOk } from "../_shared/errors.ts";
import { readJsonBody, type RequestHandler, withHttp } from "../_shared/http.ts";
import { logEvent } from "../_shared/log.ts";
import type { AppSettings } from "../_shared/settings.ts";
import {
  type EncounterRow,
  type NfcTagRow,
  type ProfessorRow,
  type Rarity,
} from "../_shared/types.ts";
import { parseTagIdentifier } from "../_shared/validate.ts";

export interface StartEncounterDeps {
  db: Db;
  now: () => Date;
  loadSettings: () => Promise<AppSettings>;
}

export interface StartEncounterInput {
  userId: string;
  tagIdentifier: string;
}

/** Response 200 of `start-encounter` (CONTRACTS §4). */
export interface StartEncounterResponse {
  encounter_id: string;
  expires_at: string;
  professor: {
    id: string;
    display_name: string;
    rarity: Rarity;
    sprite_url: string | null;
    description: string | null;
  };
}

/**
 * `{ tag_identifier: string }` (CONTRACTS §4). Validation rules live in
 * `_shared/validate.ts`; unknown extra fields are ignored.
 */
export function parseStartEncounterBody(body: Record<string, unknown>): { tagIdentifier: string } {
  return { tagIdentifier: parseTagIdentifier(body.tag_identifier) };
}

type TagLookup = Pick<NfcTagRow, "id" | "professor_id" | "active">;
type ProfessorLookup = Pick<
  ProfessorRow,
  "id" | "display_name" | "rarity" | "sprite_url" | "description" | "active"
>;
type EncounterInserted = Pick<EncounterRow, "id" | "expires_at">;

/**
 * Pure business logic: tag → professor → previous capture → expire previous ACTIVE encounters →
 * insert a new ACTIVE encounter. Runs with the service-role client (RLS bypassed).
 */
export async function handleStartEncounter(
  deps: StartEncounterDeps,
  input: StartEncounterInput,
): Promise<StartEncounterResponse> {
  const { db } = deps;
  const { userId, tagIdentifier } = input;

  // 1. Tag lookup.
  const tag = unwrap(
    await db
      .from<TagLookup>("nfc_tags")
      .select("id, professor_id, active")
      .eq("tag_identifier", tagIdentifier)
      .maybeSingle(),
    "nfc_tags.select",
  );
  if (!tag) {
    logEvent("invalid_tag", {
      user_id: userId,
      tag_identifier: tagIdentifier,
      reason: "not_found",
    });
    throw new AppError("TAG_NOT_FOUND");
  }
  if (!tag.active) {
    logEvent("invalid_tag", { user_id: userId, tag_id: tag.id, reason: "disabled" });
    throw new AppError("TAG_DISABLED");
  }

  // 2. Professor lookup (a tag without professor behaves like a disabled professor).
  const professor = tag.professor_id
    ? unwrap(
      await db
        .from<ProfessorLookup>("professors")
        .select("id, display_name, rarity, sprite_url, description, active")
        .eq("id", tag.professor_id)
        .maybeSingle(),
      "professors.select",
    )
    : null;
  if (!professor || !professor.active) {
    logEvent("professor_disabled", {
      user_id: userId,
      tag_id: tag.id,
      professor_id: tag.professor_id,
      reason: professor ? "inactive" : "missing",
    });
    throw new AppError("PROFESSOR_DISABLED");
  }

  // 3. Already in the player's collection?
  const capture = unwrap(
    await db
      .from<{ id: string }>("captures")
      .select("id")
      .eq("user_id", userId)
      .eq("professor_id", professor.id)
      .maybeSingle(),
    "captures.select",
  );
  if (capture) {
    logEvent("duplicate_capture", {
      user_id: userId,
      professor_id: professor.id,
      capture_id: capture.id,
    });
    throw new AppError("ALREADY_CAPTURED");
  }

  // 4. Previous ACTIVE encounters for this user+professor become EXPIRED.
  unwrap(
    await db
      .from("encounters")
      .update({ status: "EXPIRED" })
      .eq("user_id", userId)
      .eq("professor_id", professor.id)
      .eq("status", "ACTIVE"),
    "encounters.expire_previous",
  );

  // 5. Expiration window from app_settings (default 180 s).
  const settings = await deps.loadSettings();
  const expiresAt = new Date(deps.now().getTime() + settings.encounterExpirationSeconds * 1000);

  // 6. New encounter.
  const encounter = unwrapRequired(
    await db
      .from<EncounterInserted>("encounters")
      .insert({
        user_id: userId,
        professor_id: professor.id,
        expires_at: expiresAt.toISOString(),
        status: "ACTIVE",
      })
      .select("id, expires_at")
      .single(),
    "encounters.insert",
  );

  logEvent("encounter_started", {
    user_id: userId,
    professor_id: professor.id,
    encounter_id: encounter.id,
    tag_id: tag.id,
    expires_at: encounter.expires_at,
  });

  return {
    encounter_id: encounter.id,
    expires_at: new Date(encounter.expires_at).toISOString(),
    professor: {
      id: professor.id,
      display_name: professor.display_name,
      rarity: professor.rarity,
      sprite_url: professor.sprite_url ?? null,
      description: professor.description ?? null,
    },
  };
}

export interface StartEncounterHttpDeps extends StartEncounterDeps {
  auth: AuthVerifier;
}

/** HTTP adapter: CORS + POST + JWT + body validation around `handleStartEncounter`. */
export function createHttpHandler(deps: StartEncounterHttpDeps): RequestHandler {
  return withHttp("start-encounter", async (req) => {
    const user = await getUserFromRequest(req, deps.auth);
    const { tagIdentifier } = parseStartEncounterBody(await readJsonBody(req));
    const result = await handleStartEncounter(deps, { userId: user.id, tagIdentifier });
    return jsonOk(result);
  });
}
