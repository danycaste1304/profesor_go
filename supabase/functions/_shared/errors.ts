import { corsHeaders } from "./cors.ts";

/** Error codes returned by the Edge Functions (CONTRACTS §4) plus two transport-level codes. */
export type ErrorCode =
  | "UNAUTHORIZED"
  | "FORBIDDEN"
  | "INVALID_INPUT"
  | "TAG_NOT_FOUND"
  | "TAG_DISABLED"
  | "PROFESSOR_DISABLED"
  | "ALREADY_CAPTURED"
  | "ENCOUNTER_NOT_FOUND"
  | "ENCOUNTER_NOT_ACTIVE"
  | "ENCOUNTER_EXPIRED"
  | "PROFESSOR_NOT_FOUND"
  | "RATE_LIMITED"
  | "METHOD_NOT_ALLOWED"
  | "INTERNAL_ERROR";

/** HTTP status per error code. */
export const ERROR_STATUS: Record<ErrorCode, number> = {
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  INVALID_INPUT: 400,
  TAG_NOT_FOUND: 404,
  TAG_DISABLED: 403,
  PROFESSOR_DISABLED: 403,
  ALREADY_CAPTURED: 409,
  ENCOUNTER_NOT_FOUND: 404,
  ENCOUNTER_NOT_ACTIVE: 409,
  ENCOUNTER_EXPIRED: 410,
  PROFESSOR_NOT_FOUND: 404,
  RATE_LIMITED: 429,
  METHOD_NOT_ALLOWED: 405,
  INTERNAL_ERROR: 500,
};

/** Default user-facing messages (Spanish). */
export const ERROR_MESSAGE: Record<ErrorCode, string> = {
  UNAUTHORIZED: "Necesitas iniciar sesión para continuar.",
  FORBIDDEN: "No tienes permiso para realizar esta acción.",
  INVALID_INPUT: "Los datos enviados no son válidos.",
  TAG_NOT_FOUND: "Este tag NFC no está registrado en el juego.",
  TAG_DISABLED: "Este tag NFC está desactivado.",
  PROFESSOR_DISABLED: "Este profesor no está disponible en este momento.",
  ALREADY_CAPTURED: "Ya tienes a este profesor en tu colección.",
  ENCOUNTER_NOT_FOUND: "No se encontró el encuentro.",
  ENCOUNTER_NOT_ACTIVE: "Este encuentro ya fue resuelto.",
  ENCOUNTER_EXPIRED: "El encuentro ha expirado. Vuelve a escanear el tag NFC.",
  PROFESSOR_NOT_FOUND: "El profesor indicado no existe.",
  RATE_LIMITED: "Demasiados intentos. Espera un momento antes de volver a probar.",
  METHOD_NOT_ALLOWED: "Método no permitido. Usa POST.",
  INTERNAL_ERROR: "Ha ocurrido un error inesperado. Inténtalo de nuevo.",
};

/** Error that maps directly to an HTTP error response `{ error, message }`. */
export class AppError extends Error {
  readonly code: ErrorCode;
  readonly status: number;

  constructor(code: ErrorCode, message: string = ERROR_MESSAGE[code]) {
    super(message);
    this.name = "AppError";
    this.code = code;
    this.status = ERROR_STATUS[code];
  }
}

export interface ErrorBody {
  error: ErrorCode;
  message: string;
}

const jsonHeaders: Record<string, string> = {
  ...corsHeaders,
  "Content-Type": "application/json; charset=utf-8",
};

export function jsonOk(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

export function jsonError(code: ErrorCode, message: string = ERROR_MESSAGE[code]): Response {
  const body: ErrorBody = { error: code, message };
  return new Response(JSON.stringify(body), { status: ERROR_STATUS[code], headers: jsonHeaders });
}

/** Maps any thrown value to the JSON error shape; unknown errors become INTERNAL_ERROR (500). */
export function errorToResponse(err: unknown): Response {
  if (err instanceof AppError) return jsonError(err.code, err.message);
  return jsonError("INTERNAL_ERROR");
}
