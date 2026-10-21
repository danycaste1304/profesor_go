/**
 * Turning a PostgREST mutation result into an explicit success/error outcome.
 *
 * PostgREST reports **no error** when an UPDATE matches zero rows, so a mutation
 * that only checks `error` reports success even when nothing was written (the row
 * was deleted, the id is wrong, or RLS filtered it out). Every write therefore asks
 * for the affected rows back with `.select(...)` and passes the result through
 * `interpretWrite`, which treats "cero filas" as an error.
 *
 * Pure: no React, no Supabase imports, so it is unit-testable with vitest.
 */

/** Minimal shape of a PostgREST response (`PostgrestResponse` is assignable to it). */
export interface PostgrestWriteResult<Row> {
  data: Row[] | Row | null;
  error: { message: string } | null;
}

export type WriteOutcome<Row> = { ok: true; rows: Row[] } | { ok: false; message: string };

/** Verb used to build the Spanish error message. */
export type WriteAction = "guardar" | "crear" | "actualizar";

/** Why a write can affect zero rows, in words an admin can act on. */
export const NO_ROWS_REASON =
  "la operación no afectó a ninguna fila. Puede que el registro ya no exista o que tu sesión no tenga permisos para modificarlo.";

/**
 * Normalizes `data` (PostgREST returns an array, or a single object with `.single()`)
 * and fails when the write touched nothing.
 */
export function interpretWrite<Row>(
  result: PostgrestWriteResult<Row>,
  action: WriteAction,
  subject: string,
): WriteOutcome<Row> {
  const prefix = `No se pudo ${action} ${subject}`;

  if (result.error) {
    return { ok: false, message: `${prefix}: ${result.error.message}` };
  }

  const rows = result.data == null ? [] : Array.isArray(result.data) ? result.data : [result.data];
  if (rows.length === 0) {
    return { ok: false, message: `${prefix}: ${NO_ROWS_REASON}` };
  }

  return { ok: true, rows };
}
