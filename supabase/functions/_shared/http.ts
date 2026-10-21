import { isPreflight, preflightResponse } from "./cors.ts";
import { AppError, jsonError } from "./errors.ts";
import { logEvent } from "./log.ts";

export type RequestHandler = (req: Request) => Promise<Response>;

/**
 * Maximum accepted request body. Every contract body is a handful of short fields, so 8 KiB is
 * already generous; anything larger is rejected before it is parsed (and before it is buffered,
 * when the client declares a `Content-Length`).
 */
export const MAX_BODY_BYTES = 8 * 1024;

/** Parses the JSON body as an object; anything else (or an oversized body) is INVALID_INPUT. */
export async function readJsonBody(req: Request): Promise<Record<string, unknown>> {
  const declaredLength = Number(req.headers.get("content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    throw new AppError("INVALID_INPUT", "El cuerpo de la petición es demasiado grande.");
  }
  let text: string;
  try {
    text = await req.text();
  } catch {
    throw new AppError("INVALID_INPUT", "El cuerpo de la petición debe ser JSON válido.");
  }
  // Backstop for chunked bodies / a lying Content-Length: characters <= bytes for UTF-8.
  if (text.length > MAX_BODY_BYTES) {
    throw new AppError("INVALID_INPUT", "El cuerpo de la petición es demasiado grande.");
  }
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    throw new AppError("INVALID_INPUT", "El cuerpo de la petición debe ser JSON válido.");
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    throw new AppError("INVALID_INPUT", "El cuerpo de la petición debe ser un objeto JSON.");
  }
  return body as Record<string, unknown>;
}

/**
 * Wraps a function handler with the transport concerns every function shares:
 * CORS preflight, POST-only, and mapping thrown errors to `{ error, message }` responses.
 */
export function withHttp(fnName: string, handler: RequestHandler): RequestHandler {
  return async (req) => {
    if (isPreflight(req)) return preflightResponse();
    if (req.method !== "POST") return jsonError("METHOD_NOT_ALLOWED");
    try {
      return await handler(req);
    } catch (err) {
      if (err instanceof AppError) {
        if (err.status >= 500) logEvent("internal_error", { fn: fnName, code: err.code });
        return jsonError(err.code, err.message);
      }
      logEvent("internal_error", {
        fn: fnName,
        message: err instanceof Error ? err.message : String(err),
      });
      return jsonError("INTERNAL_ERROR");
    }
  };
}
