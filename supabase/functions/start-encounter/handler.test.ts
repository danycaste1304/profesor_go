import { assert, assertEquals, assertNotEquals, assertThrows } from "@std/assert";
import type { Row } from "../_shared/db.ts";
import { AppError } from "../_shared/errors.ts";
import { MAX_BODY_BYTES } from "../_shared/http.ts";
import { loadAppSettings } from "../_shared/settings.ts";
import { FakeDb } from "../_shared/testing/fake_db.ts";
import {
  expectAppError,
  expectErrorResponse,
  fakeAuth,
  FIXED_NOW,
  OTHER_PLAYER_ID,
  PLAYER_ID,
  PLAYER_TOKEN,
  postJson,
  PROF_COMMON_ID,
  PROF_RARE_ID,
  seededDb,
  TAG_COMMON,
  TAG_DISABLED,
  TAG_NO_PROFESSOR,
  TAG_PROF_INACTIVE,
} from "../_shared/testing/fixtures.ts";
import { isUuid } from "../_shared/types.ts";
import {
  createHttpHandler,
  handleStartEncounter,
  parseStartEncounterBody,
  type StartEncounterDeps,
} from "./handler.ts";

function makeDeps(db: FakeDb = seededDb()): StartEncounterDeps {
  return { db, now: () => FIXED_NOW, loadSettings: () => loadAppSettings(db) };
}

const playerInput = (tagIdentifier: string) => ({ userId: PLAYER_ID, tagIdentifier });

// ---------------------------------------------------------------- pure handler

Deno.test("start-encounter: valid tag creates an ACTIVE encounter and returns the professor", async () => {
  const db = seededDb();
  const result = await handleStartEncounter(makeDeps(db), playerInput(TAG_COMMON));

  assert(isUuid(result.encounter_id));
  assertEquals(result.expires_at, new Date(FIXED_NOW.getTime() + 180_000).toISOString());
  assertEquals(result.professor, {
    id: PROF_COMMON_ID,
    display_name: "Prof. Ada",
    rarity: "COMMON",
    sprite_url: "https://example.test/sprites/ada.png",
    description: "Pionera de la programación.",
  });

  const encounters = db.rows("encounters");
  assertEquals(encounters.length, 1);
  assertEquals(encounters[0].id, result.encounter_id);
  assertEquals(encounters[0].user_id, PLAYER_ID);
  assertEquals(encounters[0].professor_id, PROF_COMMON_ID);
  assertEquals(encounters[0].status, "ACTIVE");
  assertEquals(encounters[0].expires_at, result.expires_at);
});

Deno.test("start-encounter: professor with null sprite/description is returned with nulls", async () => {
  const result = await handleStartEncounter(makeDeps(), playerInput("DEMO-TAG-02"));
  assertEquals(result.professor.id, PROF_RARE_ID);
  assertEquals(result.professor.rarity, "RARE");
  assertEquals(result.professor.sprite_url, null);
  assertEquals(result.professor.description, null);
});

Deno.test("start-encounter: unknown tag -> TAG_NOT_FOUND (404)", async () => {
  const db = seededDb();
  await expectAppError(
    () => handleStartEncounter(makeDeps(db), playerInput("NOPE-TAG-99")),
    "TAG_NOT_FOUND",
    404,
  );
  assertEquals(db.rows("encounters").length, 0);
});

Deno.test("start-encounter: inactive tag -> TAG_DISABLED (403)", async () => {
  await expectAppError(
    () => handleStartEncounter(makeDeps(), playerInput(TAG_DISABLED)),
    "TAG_DISABLED",
    403,
  );
});

Deno.test("start-encounter: inactive professor -> PROFESSOR_DISABLED (403)", async () => {
  await expectAppError(
    () => handleStartEncounter(makeDeps(), playerInput(TAG_PROF_INACTIVE)),
    "PROFESSOR_DISABLED",
    403,
  );
});

Deno.test("start-encounter: tag without professor -> PROFESSOR_DISABLED (403)", async () => {
  await expectAppError(
    () => handleStartEncounter(makeDeps(), playerInput(TAG_NO_PROFESSOR)),
    "PROFESSOR_DISABLED",
    403,
  );
});

Deno.test("start-encounter: professor already captured -> ALREADY_CAPTURED (409)", async () => {
  const db = seededDb();
  db.seed("captures", [
    { user_id: PLAYER_ID, professor_id: PROF_COMMON_ID, throw_quality: "GOOD" },
  ]);
  await expectAppError(
    () => handleStartEncounter(makeDeps(db), playerInput(TAG_COMMON)),
    "ALREADY_CAPTURED",
    409,
  );
  assertEquals(db.rows("encounters").length, 0);
});

Deno.test("start-encounter: previous ACTIVE encounter of the same user+professor is EXPIRED", async () => {
  const db = seededDb();
  const future = new Date(FIXED_NOW.getTime() + 60_000).toISOString();
  const [mine, otherProfessor, otherUser, alreadyFailed] = db.seed("encounters", [
    { user_id: PLAYER_ID, professor_id: PROF_COMMON_ID, expires_at: future, status: "ACTIVE" },
    { user_id: PLAYER_ID, professor_id: PROF_RARE_ID, expires_at: future, status: "ACTIVE" },
    {
      user_id: OTHER_PLAYER_ID,
      professor_id: PROF_COMMON_ID,
      expires_at: future,
      status: "ACTIVE",
    },
    { user_id: PLAYER_ID, professor_id: PROF_COMMON_ID, expires_at: future, status: "FAILED" },
  ]);

  const result = await handleStartEncounter(makeDeps(db), playerInput(TAG_COMMON));

  assertEquals(mine.status, "EXPIRED");
  assertEquals(otherProfessor.status, "ACTIVE");
  assertEquals(otherUser.status, "ACTIVE");
  assertEquals(alreadyFailed.status, "FAILED");
  assertNotEquals(result.encounter_id, mine.id);
  const active = db
    .rows("encounters")
    .filter((e: Row) =>
      e.user_id === PLAYER_ID && e.professor_id === PROF_COMMON_ID && e.status === "ACTIVE"
    );
  assertEquals(active.length, 1);
  assertEquals(active[0].id, result.encounter_id);
});

Deno.test("start-encounter: uses app_settings.encounter_expiration_seconds when present", async () => {
  const db = seededDb();
  const setting = db.rows("app_settings").find((s) => s.key === "encounter_expiration_seconds")!;
  setting.value = 45;
  const result = await handleStartEncounter(makeDeps(db), playerInput(TAG_COMMON));
  assertEquals(result.expires_at, new Date(FIXED_NOW.getTime() + 45_000).toISOString());
});

Deno.test("start-encounter: falls back to 180 s when the setting is missing", async () => {
  const db = seededDb();
  db.tables.app_settings = [];
  const result = await handleStartEncounter(makeDeps(db), playerInput(TAG_COMMON));
  assertEquals(result.expires_at, new Date(FIXED_NOW.getTime() + 180_000).toISOString());
});

Deno.test("start-encounter: a failing query surfaces as INTERNAL_ERROR (500)", async () => {
  const db = seededDb();
  db.tables.nfc_tags = undefined as unknown as Row[]; // makes FakeDb throw on access
  await expectAppError(
    () => handleStartEncounter(makeDeps(db), playerInput(TAG_COMMON)),
    "INTERNAL_ERROR",
    500,
  );
});

// ---------------------------------------------------------------- HTTP adapter

function httpHandler(db: FakeDb = seededDb()) {
  return createHttpHandler({ ...makeDeps(db), auth: fakeAuth() });
}

Deno.test("start-encounter http: OPTIONS preflight -> 204 with CORS headers", async () => {
  const res = await httpHandler()(
    postJson("start-encounter", "", undefined, { method: "OPTIONS" }),
  );
  assertEquals(res.status, 204);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
  assert(res.headers.get("access-control-allow-headers")!.includes("authorization"));
  assert(res.headers.get("access-control-allow-methods")!.includes("POST"));
});

Deno.test("start-encounter http: GET -> 405 METHOD_NOT_ALLOWED", async () => {
  const req = new Request("http://localhost/start-encounter", { method: "GET" });
  await expectErrorResponse(await httpHandler()(req), 405, "METHOD_NOT_ALLOWED");
});

Deno.test("start-encounter http: missing Authorization -> 401 UNAUTHORIZED", async () => {
  const res = await httpHandler()(postJson("start-encounter", { tag_identifier: TAG_COMMON }));
  await expectErrorResponse(res, 401, "UNAUTHORIZED");
});

Deno.test("start-encounter http: invalid token -> 401 UNAUTHORIZED", async () => {
  const res = await httpHandler()(
    postJson("start-encounter", { tag_identifier: TAG_COMMON }, "not-a-valid-jwt"),
  );
  await expectErrorResponse(res, 401, "UNAUTHORIZED");
});

Deno.test("start-encounter http: missing tag_identifier -> 400 INVALID_INPUT", async () => {
  const res = await httpHandler()(postJson("start-encounter", {}, PLAYER_TOKEN));
  await expectErrorResponse(res, 400, "INVALID_INPUT");
});

Deno.test("start-encounter http: malformed JSON -> 400 INVALID_INPUT", async () => {
  const res = await httpHandler()(postJson("start-encounter", "{not json", PLAYER_TOKEN));
  await expectErrorResponse(res, 400, "INVALID_INPUT");
});

Deno.test("start-encounter http: unknown tag -> 404 { error, message }", async () => {
  const res = await httpHandler()(
    postJson("start-encounter", { tag_identifier: "NOPE" }, PLAYER_TOKEN),
  );
  await expectErrorResponse(res, 404, "TAG_NOT_FOUND");
});

Deno.test("start-encounter http: disabled tag -> 403, already captured -> 409", async () => {
  const db = seededDb();
  db.seed("captures", [{ user_id: PLAYER_ID, professor_id: PROF_RARE_ID, throw_quality: "GOOD" }]);
  const handler = httpHandler(db);
  await expectErrorResponse(
    await handler(postJson("start-encounter", { tag_identifier: TAG_DISABLED }, PLAYER_TOKEN)),
    403,
    "TAG_DISABLED",
  );
  await expectErrorResponse(
    await handler(postJson("start-encounter", { tag_identifier: "DEMO-TAG-02" }, PLAYER_TOKEN)),
    409,
    "ALREADY_CAPTURED",
  );
});

Deno.test("start-encounter http: valid request -> 200 with the CONTRACTS shape", async () => {
  const res = await httpHandler()(
    postJson("start-encounter", { tag_identifier: TAG_COMMON }, PLAYER_TOKEN),
  );
  assertEquals(res.status, 200);
  assert(res.headers.get("content-type")!.startsWith("application/json"));
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
  const body = await res.json();
  assertEquals(Object.keys(body).sort(), ["encounter_id", "expires_at", "professor"]);
  assertEquals(
    Object.keys(body.professor).sort(),
    ["description", "display_name", "id", "rarity", "sprite_url"],
  );
  assert(isUuid(body.encounter_id));
  assertEquals(body.professor.id, PROF_COMMON_ID);
});

// ---------------------------------------------------------------- input validation

/** Every body that must be rejected by `parseStartEncounterBody` (CONTRACTS §4: INVALID_INPUT). */
const INVALID_TAG_BODIES: Record<string, unknown>[] = [
  {},
  { tag_identifier: undefined },
  { tag_identifier: null },
  { tag_identifier: 42 },
  { tag_identifier: 0 },
  { tag_identifier: true },
  { tag_identifier: ["DEMO-TAG-01"] },
  { tag_identifier: { value: "DEMO-TAG-01" } },
  { tag_identifier: "" },
  { tag_identifier: "   " },
  { tag_identifier: "\t\n" },
  { tag_identifier: "x".repeat(129) },
  { tag_identifier: `  ${"x".repeat(129)}  ` },
  { tag_identifier: "DEMO\u0000TAG-01" },
  { tag_identifier: "DEMO\nTAG-01" },
  { tag_identifier: "DEMO\u007fTAG-01" },
  { TAG_IDENTIFIER: "DEMO-TAG-01" }, // wrong case: the key is not the contract one
];

Deno.test("start-encounter: parseStartEncounterBody rejects every invalid tag_identifier", () => {
  for (const body of INVALID_TAG_BODIES) {
    const err = assertThrows(
      () => parseStartEncounterBody(body),
      AppError,
      undefined,
      JSON.stringify(body),
    );
    assertEquals(err.code, "INVALID_INPUT", JSON.stringify(body));
    assertEquals(err.status, 400);
  }
});

Deno.test("start-encounter: parseStartEncounterBody trims, caps at 128 and ignores extra fields", () => {
  assertEquals(parseStartEncounterBody({ tag_identifier: "  DEMO-TAG-01  " }), {
    tagIdentifier: "DEMO-TAG-01",
  });
  const atLimit = "x".repeat(128);
  assertEquals(parseStartEncounterBody({ tag_identifier: atLimit }), { tagIdentifier: atLimit });
  assertEquals(parseStartEncounterBody({ tag_identifier: `  ${atLimit}  ` }), {
    tagIdentifier: atLimit,
  });
  assertEquals(parseStartEncounterBody({ tag_identifier: "DEMO-TAG-01", extra: "ignored" }), {
    tagIdentifier: "DEMO-TAG-01",
  });
});

Deno.test("start-encounter http: every invalid tag_identifier -> 400 INVALID_INPUT", async () => {
  const handler = httpHandler();
  for (const body of INVALID_TAG_BODIES) {
    await expectErrorResponse(
      await handler(postJson("start-encounter", body, PLAYER_TOKEN)),
      400,
      "INVALID_INPUT",
    );
  }
});

Deno.test("start-encounter http: a padded tag_identifier is trimmed before the lookup", async () => {
  const res = await httpHandler()(
    postJson("start-encounter", { tag_identifier: `  ${TAG_COMMON}  ` }, PLAYER_TOKEN),
  );
  assertEquals(res.status, 200);
  assertEquals((await res.json()).professor.id, PROF_COMMON_ID);
});

Deno.test("start-encounter http: an oversized body -> 400 INVALID_INPUT, never reaching the DB", async () => {
  const db = seededDb();
  const handler = httpHandler(db);
  const before = db.rows("encounters").length;
  const huge = JSON.stringify({ tag_identifier: TAG_COMMON, padding: "x".repeat(MAX_BODY_BYTES) });
  await expectErrorResponse(
    await handler(postJson("start-encounter", huge, PLAYER_TOKEN)),
    400,
    "INVALID_INPUT",
  );
  assertEquals(db.rows("encounters").length, before);
});
