import { type AuthVerifier, getUserFromRequest } from "../_shared/auth.ts";
import { type Db, unwrap } from "../_shared/db.ts";
import { AppError, jsonOk } from "../_shared/errors.ts";
import { readJsonBody, type RequestHandler, withHttp } from "../_shared/http.ts";
import { logEvent } from "../_shared/log.ts";
import type { CollectionProgress, ThrowQuality } from "../_shared/types.ts";
import { parseThrowQuality, parseUuid } from "../_shared/validate.ts";

export interface ResolveCaptureDeps {
  db: Db;
  /** Uniform random number in [0, 1). Production uses `secureRandom`. */
  random: () => number;
}

export interface ResolveCaptureInput {
  userId: string;
  encounterId: string;
  throwQuality: ThrowQuality;
}

/** Response 200 of `resolve-capture` (CONTRACTS §4). */
export type ResolveCaptureResponse =
  | { success: true; professor_id: string; collection: CollectionProgress }
  | { success: false; retry_requires_new_nfc_scan: true };

export const RPC_OUTCOMES = [
  "SUCCESS",
  "FAILED",
  "ALREADY_RESOLVED",
  "NOT_FOUND",
  "FORBIDDEN",
  "NOT_ACTIVE",
  "EXPIRED",
  "ALREADY_CAPTURED",
] as const;
export type RpcOutcome = (typeof RPC_OUTCOMES)[number];

/** Return value of `public.resolve_capture_tx` (CONTRACTS §9). */
export interface ResolveCaptureTxResult {
  outcome: RpcOutcome;
  professor_id: string | null;
  probability: number | null;
  throw_quality: string;
  collection: CollectionProgress | null;
}

/**
 * `{ encounter_id: uuid, throw_quality: MISS|GOOD|GREAT|EXCELLENT }` (CONTRACTS §4).
 * Validation rules live in `_shared/validate.ts`; unknown extra fields are ignored.
 */
export function parseResolveCaptureBody(
  body: Record<string, unknown>,
): { encounterId: string; throwQuality: ThrowQuality } {
  return {
    encounterId: parseUuid(body.encounter_id, "encounter_id"),
    throwQuality: parseThrowQuality(body.throw_quality),
  };
}

function isCollection(v: unknown): v is CollectionProgress {
  if (typeof v !== "object" || v === null) return false;
  const c = v as Record<string, unknown>;
  return typeof c.captured === "number" && typeof c.total === "number" &&
    typeof c.completed === "boolean";
}

function parseTxResult(data: unknown): ResolveCaptureTxResult {
  const raw = (typeof data === "object" && data !== null) ? data as Record<string, unknown> : {};
  const outcome = raw.outcome;
  if (typeof outcome !== "string" || !(RPC_OUTCOMES as readonly string[]).includes(outcome)) {
    logEvent("internal_error", {
      context: "resolve_capture_tx",
      message: "unknown outcome",
      outcome,
    });
    throw new AppError("INTERNAL_ERROR");
  }
  return {
    outcome: outcome as RpcOutcome,
    professor_id: typeof raw.professor_id === "string" ? raw.professor_id : null,
    probability: typeof raw.probability === "number" ? raw.probability : null,
    throw_quality: typeof raw.throw_quality === "string" ? raw.throw_quality : "",
    collection: isCollection(raw.collection) ? raw.collection : null,
  };
}

/**
 * Pure business logic: roll → atomic RPC `resolve_capture_tx` (service role) → map outcome
 * to the CONTRACTS response / error code.
 */
export async function handleResolveCapture(
  deps: ResolveCaptureDeps,
  input: ResolveCaptureInput,
): Promise<ResolveCaptureResponse> {
  const { userId, encounterId, throwQuality } = input;
  const roll = deps.random();

  const data = unwrap(
    await deps.db.rpc("resolve_capture_tx", {
      p_encounter_id: encounterId,
      p_user_id: userId,
      p_throw_quality: throwQuality,
      p_roll: roll,
    }),
    "rpc.resolve_capture_tx",
  );
  const tx = parseTxResult(data);
  const logFields = {
    user_id: userId,
    encounter_id: encounterId,
    professor_id: tx.professor_id,
    throw_quality: throwQuality,
    outcome: tx.outcome,
  };

  switch (tx.outcome) {
    case "SUCCESS":
    case "ALREADY_RESOLVED": {
      if (!tx.professor_id || !tx.collection) {
        logEvent("internal_error", { ...logFields, message: "success outcome without payload" });
        throw new AppError("INTERNAL_ERROR");
      }
      logEvent("capture_resolved", { ...logFields, success: true, probability: tx.probability });
      return { success: true, professor_id: tx.professor_id, collection: tx.collection };
    }
    case "FAILED":
      logEvent("capture_resolved", { ...logFields, success: false, probability: tx.probability });
      return { success: false, retry_requires_new_nfc_scan: true };
    case "NOT_FOUND":
      logEvent("encounter_not_found", logFields);
      throw new AppError("ENCOUNTER_NOT_FOUND");
    case "FORBIDDEN":
      logEvent("forbidden", logFields);
      throw new AppError("FORBIDDEN", "Este encuentro pertenece a otro jugador.");
    case "NOT_ACTIVE":
      logEvent("encounter_not_active", logFields);
      throw new AppError("ENCOUNTER_NOT_ACTIVE");
    case "EXPIRED":
      logEvent("encounter_expired", logFields);
      throw new AppError("ENCOUNTER_EXPIRED");
    case "ALREADY_CAPTURED":
      logEvent("duplicate_capture", logFields);
      throw new AppError("ALREADY_CAPTURED");
  }
}

export interface ResolveCaptureHttpDeps extends ResolveCaptureDeps {
  auth: AuthVerifier;
}

/** HTTP adapter: CORS + POST + JWT + body validation around `handleResolveCapture`. */
export function createHttpHandler(deps: ResolveCaptureHttpDeps): RequestHandler {
  return withHttp("resolve-capture", async (req) => {
    const user = await getUserFromRequest(req, deps.auth);
    const { encounterId, throwQuality } = parseResolveCaptureBody(await readJsonBody(req));
    const result = await handleResolveCapture(deps, { userId: user.id, encounterId, throwQuality });
    return jsonOk(result);
  });
}
