import { AppError } from "./errors.ts";
import { logEvent } from "./log.ts";

export interface AuthUser {
  id: string;
  email: string | null;
}

/** The slice of `SupabaseClient.auth` we rely on (satisfied by the real client and by test fakes). */
export interface AuthVerifier {
  getUser(jwt: string): Promise<{
    data: { user: { id: string; email?: string | null } | null };
    error: { message: string } | null;
  }>;
}

/** Extracts the raw JWT from `Authorization: Bearer <jwt>`; throws UNAUTHORIZED when absent. */
export function extractBearerToken(headers: Headers): string {
  const header = headers.get("authorization")?.trim() ?? "";
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  if (!match) throw new AppError("UNAUTHORIZED");
  return match[1];
}

/**
 * Validates the caller's JWT by asking GoTrue (`auth.getUser(jwt)` on the service-role client,
 * which checks signature and expiry server-side) and returns the user identity.
 */
export async function getUserFromRequest(req: Request, auth: AuthVerifier): Promise<AuthUser> {
  const jwt = extractBearerToken(req.headers);
  const { data, error } = await auth.getUser(jwt);
  if (error || !data.user) {
    logEvent("unauthorized", { reason: error?.message ?? "no_user" });
    throw new AppError("UNAUTHORIZED");
  }
  return { id: data.user.id, email: data.user.email ?? null };
}
