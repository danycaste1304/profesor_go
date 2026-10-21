/**
 * Minimal, structurally-typed slice of the supabase-js query builder used by the functions.
 * The real `SupabaseClient` satisfies it; `testing/fake_db.ts` provides an in-memory implementation.
 */
import { AppError } from "./errors.ts";
import { logEvent } from "./log.ts";

export type Row = Record<string, unknown>;

export interface DbError {
  message: string;
  code?: string;
  details?: string | null;
  hint?: string | null;
}

export interface DbResult<T> {
  data: T | null;
  error: DbError | null;
}

/** A query that can be awaited as a list or narrowed to one row. */
export interface ResultBuilder<T> extends PromiseLike<DbResult<T[]>> {
  single(): PromiseLike<DbResult<T>>;
  maybeSingle(): PromiseLike<DbResult<T>>;
}

export interface FilterBuilder<T> extends ResultBuilder<T> {
  eq(column: string, value: unknown): FilterBuilder<T>;
}

/** insert / upsert / update: awaitable directly, or `.select()` to read the affected rows. */
export interface MutationBuilder<T> extends PromiseLike<DbResult<unknown>> {
  eq(column: string, value: unknown): MutationBuilder<T>;
  select(columns?: string): ResultBuilder<T>;
}

export interface TableBuilder<T extends Row = Row> {
  select(columns?: string): FilterBuilder<T>;
  insert(values: Row): MutationBuilder<T>;
  upsert(values: Row, options?: { onConflict?: string }): MutationBuilder<T>;
  update(values: Row): MutationBuilder<T>;
}

export interface Db {
  from<T extends Row = Row>(table: string): TableBuilder<T>;
  rpc(fn: string, args?: Record<string, unknown>): PromiseLike<DbResult<unknown>>;
}

/** Returns `data` or throws INTERNAL_ERROR (logging the DB error) when the query failed. */
export function unwrap<T>(result: DbResult<T>, context: string): T | null {
  if (result.error) {
    logEvent("db_error", { context, message: result.error.message, code: result.error.code });
    throw new AppError("INTERNAL_ERROR");
  }
  return result.data;
}

/** Like `unwrap` but a missing row is also an internal error (used after insert/upsert). */
export function unwrapRequired<T>(result: DbResult<T>, context: string): T {
  const data = unwrap(result, context);
  if (data === null || data === undefined) {
    logEvent("db_error", { context, message: "expected a row, got none" });
    throw new AppError("INTERNAL_ERROR");
  }
  return data;
}
