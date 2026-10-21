/** Shared test fixtures: a seeded FakeDb, a fake JWT verifier and small HTTP helpers. */
import { assert, assertEquals, assertRejects } from "@std/assert";
import type { AuthVerifier } from "../auth.ts";
import { AppError, type ErrorCode } from "../errors.ts";
import { setLogSink } from "../log.ts";
import { FakeDb } from "./fake_db.ts";

// Keep test output free of structured log lines.
setLogSink(() => {});

export const FIXED_NOW = new Date("2026-09-16T12:00:00.000Z");

export const PLAYER_ID = "11111111-1111-4111-8111-111111111111";
export const OTHER_PLAYER_ID = "22222222-2222-4222-8222-222222222222";
export const ADMIN_ID = "33333333-3333-4333-8333-333333333333";

export const PROF_COMMON_ID = "00000000-0000-4000-8000-000000000001";
export const PROF_RARE_ID = "00000000-0000-4000-8000-000000000002";
export const PROF_INACTIVE_ID = "00000000-0000-4000-8000-000000000003";

export const TAG_COMMON = "DEMO-TAG-01";
export const TAG_RARE = "DEMO-TAG-02";
export const TAG_DISABLED = "DEMO-TAG-03";
export const TAG_PROF_INACTIVE = "DEMO-TAG-04";
export const TAG_NO_PROFESSOR = "DEMO-TAG-05";

export const PLAYER_TOKEN = "token-player";
export const OTHER_PLAYER_TOKEN = "token-other-player";
export const ADMIN_TOKEN = "token-admin";

export function seededDb(now: () => Date = () => FIXED_NOW): FakeDb {
  const db = new FakeDb(now);
  db.seed("profiles", [
    { id: PLAYER_ID, email: "player@profesorgo.local", display_name: "Jugador", role: "player" },
    { id: OTHER_PLAYER_ID, email: "other@profesorgo.local", display_name: "Otro", role: "player" },
    { id: ADMIN_ID, email: "admin@profesorgo.local", display_name: "Admin", role: "admin" },
  ]);
  db.seed("professors", [
    {
      id: PROF_COMMON_ID,
      name: "Ada Lovelace",
      display_name: "Prof. Ada",
      description: "Pionera de la programación.",
      rarity: "COMMON",
      sprite_url: "https://example.test/sprites/ada.png",
      active: true,
      base_capture_rate: 0.8,
    },
    {
      id: PROF_RARE_ID,
      name: "Edsger Dijkstra",
      display_name: "Prof. Dijkstra",
      description: null,
      rarity: "RARE",
      sprite_url: null,
      active: true,
      base_capture_rate: 0.6,
    },
    {
      id: PROF_INACTIVE_ID,
      name: "Donald Knuth",
      display_name: "Prof. Knuth",
      rarity: "EPIC",
      active: false,
      base_capture_rate: 0.4,
    },
  ]);
  db.seed("nfc_tags", [
    { tag_identifier: TAG_COMMON, professor_id: PROF_COMMON_ID, active: true },
    { tag_identifier: TAG_RARE, professor_id: PROF_RARE_ID, active: true },
    { tag_identifier: TAG_DISABLED, professor_id: PROF_COMMON_ID, active: false },
    { tag_identifier: TAG_PROF_INACTIVE, professor_id: PROF_INACTIVE_ID, active: true },
    { tag_identifier: TAG_NO_PROFESSOR, professor_id: null, active: true },
  ]);
  db.seed("app_settings", [
    { key: "encounter_expiration_seconds", value: 180 },
    { key: "throw_bonus", value: { MISS: -1.0, GOOD: 0.0, GREAT: 0.10, EXCELLENT: 0.20 } },
  ]);
  return db;
}

/** Fake GoTrue: maps known bearer tokens to users; anything else is an invalid JWT. */
export function fakeAuth(): AuthVerifier {
  const users = new Map<string, { id: string; email: string }>([
    [PLAYER_TOKEN, { id: PLAYER_ID, email: "player@profesorgo.local" }],
    [OTHER_PLAYER_TOKEN, { id: OTHER_PLAYER_ID, email: "other@profesorgo.local" }],
    [ADMIN_TOKEN, { id: ADMIN_ID, email: "admin@profesorgo.local" }],
  ]);
  return {
    getUser(jwt: string) {
      const user = users.get(jwt);
      return Promise.resolve(
        user
          ? { data: { user }, error: null }
          : { data: { user: null }, error: { message: "invalid JWT" } },
      );
    },
  };
}

export function postJson(
  fn: string,
  body: unknown,
  token?: string,
  init: { method?: string } = {},
): Request {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  return new Request(`http://localhost:54321/functions/v1/${fn}`, {
    method: init.method ?? "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

export async function expectAppError(
  fn: () => Promise<unknown>,
  code: ErrorCode,
  status: number,
): Promise<AppError> {
  const err = await assertRejects(fn, AppError);
  assertEquals(err.code, code, `expected ${code} but got ${err.code} (${err.message})`);
  assertEquals(err.status, status);
  return err;
}

/** Asserts the CONTRACTS error payload shape: exactly `{ error, message }` with the given status. */
export async function expectErrorResponse(
  res: Response,
  status: number,
  code: ErrorCode,
): Promise<void> {
  const body = await res.json();
  assertEquals(
    res.status,
    status,
    `expected ${status}, got ${res.status}: ${JSON.stringify(body)}`,
  );
  assertEquals(Object.keys(body).sort(), ["error", "message"]);
  assertEquals(body.error, code);
  assert(typeof body.message === "string" && body.message.length > 0);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
}
