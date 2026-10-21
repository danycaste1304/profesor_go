/**
 * In-memory fake of the query-builder surface declared in `../db.ts`, plus a faithful
 * re-implementation of the `resolve_capture_tx` RPC (CONTRACTS §9) so resolve-capture
 * can be tested end to end without a database.
 */
import type {
  Db,
  DbError,
  DbResult,
  FilterBuilder,
  MutationBuilder,
  Row,
  TableBuilder,
} from "../db.ts";
import { DEFAULT_THROW_BONUS } from "../settings.ts";
import { type CollectionProgress, isThrowQuality, type ThrowQuality } from "../types.ts";

type Filter = { column: string; value: unknown };
type Op = "select" | "insert" | "upsert" | "update";
type UpsertOptions = { onConflict?: string };

const TABLES = ["profiles", "professors", "nfc_tags", "encounters", "captures", "app_settings"];

const UNIQUE_KEYS: Record<string, string[][]> = {
  profiles: [["id"]],
  professors: [["id"]],
  nfc_tags: [["id"], ["tag_identifier"]],
  encounters: [["id"]],
  captures: [["id"], ["user_id", "professor_id"]],
  app_settings: [["key"]],
};

const COLUMN_DEFAULTS: Record<string, () => Row> = {
  profiles: () => ({ display_name: null, role: "player", collection_completed_at: null }),
  professors: () => ({ description: null, sprite_url: null, active: true }),
  nfc_tags: () => ({ professor_id: null, active: true }),
  encounters: () => ({ status: "ACTIVE" }),
  captures: () => ({ encounter_id: null }),
  app_settings: () => ({}),
};

export class FakeDb implements Db {
  readonly tables: Record<string, Row[]> = Object.fromEntries(TABLES.map((t) => [t, []]));

  constructor(readonly now: () => Date = () => new Date()) {}

  /** Stores rows directly (like a SQL seed), filling `id`/`created_at` defaults. Returns the stored rows. */
  seed(table: string, rows: Row[]): Row[] {
    return rows.map((row) => this.store(table, row));
  }

  rows(table: string): Row[] {
    return this.table(table);
  }

  from<T extends Row = Row>(table: string): TableBuilder<T> {
    // Unknown tables surface as query errors at execution time, like PostgREST does.
    return new FakeTable<T>(this, table);
  }

  rpc(fn: string, args: Record<string, unknown> = {}): Promise<DbResult<unknown>> {
    if (fn === "resolve_capture_tx") return Promise.resolve(resolveCaptureTx(this, args));
    return Promise.resolve({
      data: null,
      error: { message: `function public.${fn} does not exist`, code: "42883" },
    });
  }

  table(name: string): Row[] {
    const rows = this.tables[name];
    if (!rows) throw new Error(`FakeDb: unknown table "${name}"`);
    return rows;
  }

  store(table: string, row: Row): Row {
    const stored: Row = { ...COLUMN_DEFAULTS[table]?.(), ...row };
    if (table !== "app_settings") {
      if (stored.id === undefined) stored.id = crypto.randomUUID();
      if (stored.created_at === undefined) stored.created_at = this.now().toISOString();
    }
    if (table === "captures" && stored.captured_at === undefined) {
      stored.captured_at = this.now().toISOString();
    }
    this.table(table).push(stored);
    return stored;
  }

  uniqueViolation(table: string, row: Row): DbError | null {
    for (const keys of UNIQUE_KEYS[table] ?? []) {
      if (keys.some((k) => row[k] === undefined)) continue;
      const clash = this.table(table).some((existing) => keys.every((k) => existing[k] === row[k]));
      if (clash) {
        return {
          message: `duplicate key value violates unique constraint "${table}_${
            keys.join("_")
          }_key"`,
          code: "23505",
        };
      }
    }
    return null;
  }
}

class FakeTable<T extends Row> implements TableBuilder<T> {
  constructor(private readonly db: FakeDb, private readonly table: string) {}

  select(columns?: string): FilterBuilder<T> {
    return new FakeQuery<T>(this.db, this.table, "select", undefined, undefined, columns ?? "*");
  }

  insert(values: Row): MutationBuilder<T> {
    return new FakeQuery<T>(this.db, this.table, "insert", values);
  }

  upsert(values: Row, options?: UpsertOptions): MutationBuilder<T> {
    return new FakeQuery<T>(this.db, this.table, "upsert", values, options);
  }

  update(values: Row): MutationBuilder<T> {
    return new FakeQuery<T>(this.db, this.table, "update", values);
  }
}

class FakeQuery<T extends Row> implements FilterBuilder<T>, MutationBuilder<T> {
  private readonly filters: Filter[] = [];
  private columns: string | null;

  constructor(
    private readonly db: FakeDb,
    private readonly table: string,
    private readonly op: Op,
    private readonly values?: Row,
    private readonly options?: UpsertOptions,
    columns?: string,
  ) {
    this.columns = columns ?? null;
  }

  eq(column: string, value: unknown): this {
    this.filters.push({ column, value });
    return this;
  }

  select(columns?: string): this {
    this.columns = columns ?? "*";
    return this;
  }

  single(): Promise<DbResult<T>> {
    return this.run().then((res) => {
      if (res.error) return { data: null, error: res.error };
      const rows = res.data ?? [];
      if (rows.length !== 1) return { data: null, error: notSingle(rows.length) };
      return { data: rows[0], error: null };
    });
  }

  maybeSingle(): Promise<DbResult<T>> {
    return this.run().then((res) => {
      if (res.error) return { data: null, error: res.error };
      const rows = res.data ?? [];
      if (rows.length > 1) return { data: null, error: notSingle(rows.length) };
      return { data: rows[0] ?? null, error: null };
    });
  }

  then<R1 = DbResult<T[]>, R2 = never>(
    onfulfilled?: ((value: DbResult<T[]>) => R1 | PromiseLike<R1>) | null,
    onrejected?: ((reason: unknown) => R2 | PromiseLike<R2>) | null,
  ): Promise<R1 | R2> {
    return this.run().then(onfulfilled, onrejected);
  }

  private run(): Promise<DbResult<T[]>> {
    try {
      return Promise.resolve(this.execute());
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return Promise.resolve({ data: null, error: { message } });
    }
  }

  private execute(): DbResult<T[]> {
    const rows = this.db.table(this.table);
    const matches = (row: Row) => this.filters.every((f) => row[f.column] === f.value);
    const values = this.values ?? {};
    switch (this.op) {
      case "select":
        return { data: rows.filter(matches).map((r) => this.project(r)), error: null };
      case "insert": {
        const violation = this.db.uniqueViolation(this.table, values);
        if (violation) return { data: null, error: violation };
        return this.returning([this.db.store(this.table, values)]);
      }
      case "upsert": {
        const keys = (this.options?.onConflict ?? "id").split(",").map((k) => k.trim());
        const existing = rows.find((r) =>
          keys.every((k) => values[k] !== undefined && r[k] === values[k])
        );
        if (existing) {
          Object.assign(existing, values);
          return this.returning([existing]);
        }
        const violation = this.db.uniqueViolation(this.table, values);
        if (violation) return { data: null, error: violation };
        return this.returning([this.db.store(this.table, values)]);
      }
      case "update": {
        const targets = rows.filter(matches);
        for (const row of targets) Object.assign(row, values);
        return this.returning(targets);
      }
    }
  }

  private returning(rows: Row[]): DbResult<T[]> {
    if (this.columns === null) return { data: null, error: null };
    return { data: rows.map((r) => this.project(r)), error: null };
  }

  private project(row: Row): T {
    if (this.columns === null || this.columns.trim() === "*") return { ...row } as T;
    const out: Row = {};
    for (const col of this.columns.split(",").map((c) => c.trim()).filter(Boolean)) {
      out[col] = row[col];
    }
    return out as T;
  }
}

function notSingle(count: number): DbError {
  return {
    message: `JSON object requested, multiple (or no) rows returned (${count} rows)`,
    code: "PGRST116",
  };
}

// ---------------------------------------------------------------------------------------------
// resolve_capture_tx (CONTRACTS §9), mirrored in memory.
// ---------------------------------------------------------------------------------------------

export function collectionProgress(db: FakeDb, userId: string): CollectionProgress {
  const activeIds = new Set(
    db.table("professors").filter((p) => p.active === true).map((p) => p.id as string),
  );
  const captured = db
    .table("captures")
    .filter((c) => c.user_id === userId && activeIds.has(c.professor_id as string)).length;
  const total = activeIds.size;
  return { captured, total, completed: total > 0 && captured >= total };
}

function throwBonus(db: FakeDb, quality: ThrowQuality): number {
  const row = db.table("app_settings").find((s) => s.key === "throw_bonus");
  const value = row?.value as Record<string, unknown> | undefined;
  const bonus = value?.[quality];
  return typeof bonus === "number" ? bonus : DEFAULT_THROW_BONUS[quality];
}

function resolveCaptureTx(db: FakeDb, args: Record<string, unknown>): DbResult<unknown> {
  const quality = args.p_throw_quality;
  if (!isThrowQuality(quality)) {
    return {
      data: null,
      error: { message: `invalid throw_quality: ${String(quality)}`, code: "23514" },
    };
  }
  const encounterId = args.p_encounter_id;
  const userId = args.p_user_id;
  const roll = typeof args.p_roll === "number" ? args.p_roll : Math.random();

  const result = (outcome: string, extra: Row = {}): DbResult<unknown> => ({
    data: {
      outcome,
      professor_id: null,
      probability: null,
      throw_quality: quality,
      collection: null,
      ...extra,
    },
    error: null,
  });

  const encounter = db.table("encounters").find((e) => e.id === encounterId);
  if (!encounter) return result("NOT_FOUND");
  if (encounter.user_id !== userId) return result("FORBIDDEN");

  const professorId = encounter.professor_id as string;
  const existingCapture = db
    .table("captures")
    .find((c) => c.user_id === userId && c.professor_id === professorId);

  if (encounter.status === "SUCCESS" && existingCapture) {
    return result("ALREADY_RESOLVED", {
      professor_id: professorId,
      collection: collectionProgress(db, userId as string),
    });
  }
  if (encounter.status !== "ACTIVE") return result("NOT_ACTIVE", { professor_id: professorId });
  if (new Date(encounter.expires_at as string).getTime() < db.now().getTime()) {
    encounter.status = "EXPIRED";
    return result("EXPIRED", { professor_id: professorId });
  }
  if (existingCapture) {
    encounter.status = "EXPIRED";
    return result("ALREADY_CAPTURED", { professor_id: professorId });
  }

  const professor = db.table("professors").find((p) => p.id === professorId);
  const base = Number(professor?.base_capture_rate ?? 0);
  const probability = Math.min(1, Math.max(0, base + throwBonus(db, quality)));

  if (roll < probability) {
    encounter.status = "SUCCESS";
    db.store("captures", {
      user_id: userId,
      professor_id: professorId,
      encounter_id: encounter.id,
      throw_quality: quality,
    });
    const collection = collectionProgress(db, userId as string);
    if (collection.completed) {
      const profile = db.table("profiles").find((p) => p.id === userId);
      if (profile && !profile.collection_completed_at) {
        profile.collection_completed_at = db.now().toISOString();
      }
    }
    return result("SUCCESS", { professor_id: professorId, probability, collection });
  }

  encounter.status = "FAILED";
  return result("FAILED", { professor_id: professorId, probability });
}
