import { type AuthVerifier, getUserFromRequest } from "../_shared/auth.ts";
import { type Db, unwrap, unwrapRequired } from "../_shared/db.ts";
import { AppError, jsonOk } from "../_shared/errors.ts";
import { readJsonBody, type RequestHandler, withHttp } from "../_shared/http.ts";
import { logEvent } from "../_shared/log.ts";
import type { NfcTagRow } from "../_shared/types.ts";
import {
  parseOptionalBoolean,
  parseOptionalUuid,
  parseTagIdentifier,
} from "../_shared/validate.ts";

export interface AdminRegisterNfcDeps {
  db: Db;
}

export interface AdminRegisterNfcInput {
  /** Caller (must have profiles.role = 'admin'). */
  userId: string;
  tagIdentifier: string;
  professorId: string | null;
  active: boolean;
}

/** Response 200 of `admin-register-nfc` (CONTRACTS §4). */
export interface AdminRegisterNfcResponse {
  tag: NfcTagRow;
}

/**
 * `{ tag_identifier: string, professor_id: uuid|null, active?: boolean }` (CONTRACTS §4).
 * Validation rules live in `_shared/validate.ts`; unknown extra fields are ignored.
 */
export function parseAdminRegisterNfcBody(
  body: Record<string, unknown>,
): { tagIdentifier: string; professorId: string | null; active: boolean } {
  return {
    tagIdentifier: parseTagIdentifier(body.tag_identifier),
    professorId: parseOptionalUuid(body.professor_id, "professor_id"),
    active: parseOptionalBoolean(body.active, "active", true),
  };
}

/** Throws FORBIDDEN unless `profiles.role = 'admin'` for the caller. */
export async function requireAdmin(db: Db, userId: string): Promise<void> {
  const profile = unwrap(
    await db.from<{ role: string }>("profiles").select("role").eq("id", userId).maybeSingle(),
    "profiles.select",
  );
  if (profile?.role !== "admin") {
    logEvent("forbidden", { user_id: userId, reason: "not_admin" });
    throw new AppError("FORBIDDEN", "Solo los administradores pueden registrar tags NFC.");
  }
}

/** Pure business logic: admin check → professor exists → upsert nfc_tags by tag_identifier. */
export async function handleAdminRegisterNfc(
  deps: AdminRegisterNfcDeps,
  input: AdminRegisterNfcInput,
): Promise<AdminRegisterNfcResponse> {
  const { db } = deps;
  await requireAdmin(db, input.userId);

  if (input.professorId) {
    const professor = unwrap(
      await db.from<{ id: string }>("professors").select("id").eq("id", input.professorId)
        .maybeSingle(),
      "professors.select",
    );
    if (!professor) {
      logEvent("professor_not_found", { user_id: input.userId, professor_id: input.professorId });
      throw new AppError("PROFESSOR_NOT_FOUND");
    }
  }

  const tag = unwrapRequired(
    await db
      .from<NfcTagRow>("nfc_tags")
      .upsert(
        {
          tag_identifier: input.tagIdentifier,
          professor_id: input.professorId,
          active: input.active,
        },
        { onConflict: "tag_identifier" },
      )
      .select("id, tag_identifier, professor_id, active, created_at")
      .single(),
    "nfc_tags.upsert",
  );

  logEvent("nfc_tag_registered", {
    admin_id: input.userId,
    tag_id: tag.id,
    tag_identifier: tag.tag_identifier,
    professor_id: tag.professor_id,
    active: tag.active,
  });

  return {
    tag: {
      id: tag.id,
      tag_identifier: tag.tag_identifier,
      professor_id: tag.professor_id ?? null,
      active: tag.active,
      created_at: tag.created_at,
    },
  };
}

export interface AdminRegisterNfcHttpDeps extends AdminRegisterNfcDeps {
  auth: AuthVerifier;
}

/** HTTP adapter: CORS + POST + JWT + body validation around `handleAdminRegisterNfc`. */
export function createHttpHandler(deps: AdminRegisterNfcHttpDeps): RequestHandler {
  return withHttp("admin-register-nfc", async (req) => {
    const user = await getUserFromRequest(req, deps.auth);
    const parsed = parseAdminRegisterNfcBody(await readJsonBody(req));
    const result = await handleAdminRegisterNfc(deps, { userId: user.id, ...parsed });
    return jsonOk(result);
  });
}
