import { assert, assertEquals, assertThrows } from "@std/assert";
import type { Db, Row } from "../_shared/db.ts";
import { AppError } from "../_shared/errors.ts";
import { MAX_BODY_BYTES } from "../_shared/http.ts";
import { FakeDb } from "../_shared/testing/fake_db.ts";
import {
  expectAppError,
  expectErrorResponse,
  fakeAuth,
  FIXED_NOW,
  OTHER_PLAYER_ID,
  OTHER_PLAYER_TOKEN,
  PLAYER_ID,
  PLAYER_TOKEN,
  postJson,
  PROF_COMMON_ID,
  PROF_RARE_ID,
  seededDb,
} from "../_shared/testing/fixtures.ts";
import type { ThrowQuality } from "../_shared/types.ts";
import {
  createHttpHandler,
  handleResolveCapture,
  parseResolveCaptureBody,
  type ResolveCaptureDeps,
} from "./handler.ts";

const FUTURE = new Date(FIXED_NOW.getTime() + 120_000).toISOString();
const PAST = new Date(FIXED_NOW.getTime() - 1_000).toISOString();

function activeEncounter(db: FakeDb, overrides: Row = {}): Row {
  const [row] = db.seed("encounters", [
    {
      user_id: PLAYER_ID,
      professor_id: PROF_COMMON_ID,
      expires_at: FUTURE,
      status: "ACTIVE",
      ...overrides,
    },
  ]);
  return row;
}

function makeDeps(db: FakeDb, roll: number): ResolveCaptureDeps {
  return { db, random: () => roll };
}

function input(encounterId: unknown, throwQuality: ThrowQuality = "GOOD", userId = PLAYER_ID) {
  return { userId, encounterId: encounterId as string, throwQuality };
}

// ---------------------------------------------------------------- pure handler

Deno.test("resolve-capture: roll below probability -> success, capture stored, encounter SUCCESS", async () => {
  const db = seededDb();
  const enc = activeEncounter(db);

  const result = await handleResolveCapture(makeDeps(db, 0.5), input(enc.id, "GOOD"));

  assertEquals(result, {
    success: true,
    professor_id: PROF_COMMON_ID,
    collection: { captured: 1, total: 2, completed: false },
  });
  assertEquals(enc.status, "SUCCESS");
  const captures = db.rows("captures");
  assertEquals(captures.length, 1);
  assertEquals(captures[0].user_id, PLAYER_ID);
  assertEquals(captures[0].professor_id, PROF_COMMON_ID);
  assertEquals(captures[0].encounter_id, enc.id);
  assertEquals(captures[0].throw_quality, "GOOD");
});

Deno.test("resolve-capture: roll at/above probability -> failure requiring a new NFC scan", async () => {
  const db = seededDb();
  const enc = activeEncounter(db);

  const result = await handleResolveCapture(makeDeps(db, 0.95), input(enc.id, "GOOD"));

  assertEquals(result, { success: false, retry_requires_new_nfc_scan: true });
  assertEquals(enc.status, "FAILED");
  assertEquals(db.rows("captures").length, 0);
});

Deno.test("resolve-capture: throw bonus applies (GREAT turns a 0.85 roll into a success on COMMON)", async () => {
  const db = seededDb();
  const enc = activeEncounter(db);
  const result = await handleResolveCapture(makeDeps(db, 0.85), input(enc.id, "GREAT"));
  assertEquals(result.success, true);
});

Deno.test("resolve-capture: MISS always fails, even with roll 0", async () => {
  const db = seededDb();
  const enc = activeEncounter(db);
  const result = await handleResolveCapture(makeDeps(db, 0), input(enc.id, "MISS"));
  assertEquals(result, { success: false, retry_requires_new_nfc_scan: true });
  assertEquals(enc.status, "FAILED");
});

Deno.test("resolve-capture: expired encounter -> ENCOUNTER_EXPIRED (410) and marked EXPIRED", async () => {
  const db = seededDb();
  const enc = activeEncounter(db, { expires_at: PAST });
  await expectAppError(
    () => handleResolveCapture(makeDeps(db, 0), input(enc.id)),
    "ENCOUNTER_EXPIRED",
    410,
  );
  assertEquals(enc.status, "EXPIRED");
  assertEquals(db.rows("captures").length, 0);
});

Deno.test("resolve-capture: encounter of another user -> FORBIDDEN (403), untouched", async () => {
  const db = seededDb();
  const enc = activeEncounter(db);
  await expectAppError(
    () => handleResolveCapture(makeDeps(db, 0), input(enc.id, "GOOD", OTHER_PLAYER_ID)),
    "FORBIDDEN",
    403,
  );
  assertEquals(enc.status, "ACTIVE");
});

Deno.test("resolve-capture: unknown encounter -> ENCOUNTER_NOT_FOUND (404)", async () => {
  const db = seededDb();
  await expectAppError(
    () => handleResolveCapture(makeDeps(db, 0), input("99999999-9999-4999-8999-999999999999")),
    "ENCOUNTER_NOT_FOUND",
    404,
  );
});

Deno.test("resolve-capture: resolving a SUCCESS encounter again is idempotent", async () => {
  const db = seededDb();
  const enc = activeEncounter(db);
  const deps = makeDeps(db, 0.1);

  const first = await handleResolveCapture(deps, input(enc.id, "EXCELLENT"));
  const second = await handleResolveCapture({ db, random: () => 0.99 }, input(enc.id, "MISS"));

  assertEquals(first, second);
  assertEquals(db.rows("captures").length, 1);
  assertEquals(enc.status, "SUCCESS");
});

Deno.test("resolve-capture: FAILED encounter cannot be retried -> ENCOUNTER_NOT_ACTIVE (409)", async () => {
  const db = seededDb();
  const enc = activeEncounter(db, { status: "FAILED" });
  await expectAppError(
    () => handleResolveCapture(makeDeps(db, 0), input(enc.id)),
    "ENCOUNTER_NOT_ACTIVE",
    409,
  );
  assertEquals(enc.status, "FAILED");
});

Deno.test("resolve-capture: professor captured via another encounter -> ALREADY_CAPTURED (409), encounter EXPIRED", async () => {
  const db = seededDb();
  db.seed("captures", [{
    user_id: PLAYER_ID,
    professor_id: PROF_COMMON_ID,
    throw_quality: "GOOD",
  }]);
  const enc = activeEncounter(db);
  await expectAppError(
    () => handleResolveCapture(makeDeps(db, 0), input(enc.id)),
    "ALREADY_CAPTURED",
    409,
  );
  assertEquals(enc.status, "EXPIRED");
  assertEquals(db.rows("captures").length, 1);
});

Deno.test("resolve-capture: capturing the last active professor completes the collection", async () => {
  const db = seededDb();
  db.seed("captures", [{ user_id: PLAYER_ID, professor_id: PROF_RARE_ID, throw_quality: "GOOD" }]);
  const enc = activeEncounter(db);

  const result = await handleResolveCapture(makeDeps(db, 0.2), input(enc.id));

  assertEquals(result, {
    success: true,
    professor_id: PROF_COMMON_ID,
    collection: { captured: 2, total: 2, completed: true },
  });
  const profile = db.rows("profiles").find((p) => p.id === PLAYER_ID)!;
  assertEquals(profile.collection_completed_at, FIXED_NOW.toISOString());
});

Deno.test("resolve-capture: passes user, encounter, quality and the generated roll to the RPC", async () => {
  const db = seededDb();
  const enc = activeEncounter(db);
  let seen: Record<string, unknown> | undefined;
  const spy: Db = {
    from: (table) => db.from(table),
    rpc: (fn, args) => {
      seen = { fn, ...args };
      return db.rpc(fn, args);
    },
  };

  await handleResolveCapture({ db: spy, random: () => 0.42 }, input(enc.id, "GREAT"));

  assertEquals(seen, {
    fn: "resolve_capture_tx",
    p_encounter_id: enc.id,
    p_user_id: PLAYER_ID,
    p_throw_quality: "GREAT",
    p_roll: 0.42,
  });
});

Deno.test("resolve-capture: an RPC error or a malformed outcome -> INTERNAL_ERROR (500)", async () => {
  const failing: Db = {
    from: () => {
      throw new Error("unused");
    },
    rpc: () => Promise.resolve({ data: null, error: { message: "boom" } }),
  };
  await expectAppError(
    () => handleResolveCapture({ db: failing, random: () => 0 }, input(crypto.randomUUID())),
    "INTERNAL_ERROR",
    500,
  );
  const weird: Db = {
    ...failing,
    rpc: () => Promise.resolve({ data: { outcome: "WHAT" }, error: null }),
  };
  await expectAppError(
    () => handleResolveCapture({ db: weird, random: () => 0 }, input(crypto.randomUUID())),
    "INTERNAL_ERROR",
    500,
  );
});

// ---------------------------------------------------------------- input validation

Deno.test("resolve-capture: invalid input is rejected with INVALID_INPUT", () => {
  const bad: Record<string, unknown>[] = [
    {},
    { encounter_id: "not-a-uuid", throw_quality: "GOOD" },
    { encounter_id: crypto.randomUUID() },
    { encounter_id: crypto.randomUUID(), throw_quality: "good" },
    { encounter_id: crypto.randomUUID(), throw_quality: "PERFECT" },
    { encounter_id: 123, throw_quality: "GOOD" },
  ];
  for (const body of bad) {
    let thrown: unknown;
    try {
      parseResolveCaptureBody(body);
    } catch (err) {
      thrown = err;
    }
    assert(thrown instanceof AppError, `expected AppError for ${JSON.stringify(body)}`);
    assertEquals(thrown.code, "INVALID_INPUT");
  }
  const id = crypto.randomUUID();
  assertEquals(parseResolveCaptureBody({ encounter_id: id, throw_quality: "EXCELLENT" }), {
    encounterId: id,
    throwQuality: "EXCELLENT",
  });
});

// ---------------------------------------------------------------- HTTP adapter

function httpHandler(db: FakeDb, roll: number) {
  return createHttpHandler({ db, random: () => roll, auth: fakeAuth() });
}

Deno.test("resolve-capture http: success and failure payloads (200)", async () => {
  const db = seededDb();
  const enc = activeEncounter(db);
  const body = { encounter_id: enc.id, throw_quality: "GOOD" };

  const fail = await httpHandler(db, 0.99)(postJson("resolve-capture", body, PLAYER_TOKEN));
  assertEquals(fail.status, 200);
  assertEquals(await fail.json(), { success: false, retry_requires_new_nfc_scan: true });

  const enc2 = activeEncounter(db);
  const ok = await httpHandler(db, 0.01)(
    postJson("resolve-capture", { ...body, encounter_id: enc2.id }, PLAYER_TOKEN),
  );
  assertEquals(ok.status, 200);
  assertEquals(await ok.json(), {
    success: true,
    professor_id: PROF_COMMON_ID,
    collection: { captured: 1, total: 2, completed: false },
  });
});

Deno.test("resolve-capture http: error status mapping", async () => {
  const db = seededDb();
  const handler = httpHandler(db, 0);
  const call = (body: unknown) => handler(postJson("resolve-capture", body, PLAYER_TOKEN));

  await expectErrorResponse(
    await call({ encounter_id: "x", throw_quality: "GOOD" }),
    400,
    "INVALID_INPUT",
  );
  await expectErrorResponse(
    await handler(
      postJson("resolve-capture", { encounter_id: crypto.randomUUID(), throw_quality: "GOOD" }),
    ),
    401,
    "UNAUTHORIZED",
  );
  await expectErrorResponse(
    await call({ encounter_id: crypto.randomUUID(), throw_quality: "GOOD" }),
    404,
    "ENCOUNTER_NOT_FOUND",
  );

  const foreign = activeEncounter(db, { user_id: OTHER_PLAYER_ID });
  await expectErrorResponse(
    await call({ encounter_id: foreign.id, throw_quality: "GOOD" }),
    403,
    "FORBIDDEN",
  );
  const okForOwner = await handler(
    postJson(
      "resolve-capture",
      { encounter_id: foreign.id, throw_quality: "GOOD" },
      OTHER_PLAYER_TOKEN,
    ),
  );
  assertEquals(okForOwner.status, 200);

  const failed = activeEncounter(db, { status: "FAILED" });
  await expectErrorResponse(
    await call({ encounter_id: failed.id, throw_quality: "GOOD" }),
    409,
    "ENCOUNTER_NOT_ACTIVE",
  );

  const expired = activeEncounter(db, { expires_at: PAST });
  await expectErrorResponse(
    await call({ encounter_id: expired.id, throw_quality: "GOOD" }),
    410,
    "ENCOUNTER_EXPIRED",
  );

  db.seed("captures", [{ user_id: PLAYER_ID, professor_id: PROF_RARE_ID, throw_quality: "GOOD" }]);
  const dup = activeEncounter(db, { professor_id: PROF_RARE_ID });
  await expectErrorResponse(
    await call({ encounter_id: dup.id, throw_quality: "GOOD" }),
    409,
    "ALREADY_CAPTURED",
  );
});

Deno.test("resolve-capture http: OPTIONS preflight -> 204", async () => {
  const res = await httpHandler(seededDb(), 0)(
    postJson("resolve-capture", "", undefined, { method: "OPTIONS" }),
  );
  assertEquals(res.status, 204);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
});

// ------------------------------------------------- input validation (strict field rules)

const VALID_UUID = "00000000-0000-4000-8000-000000000001";

/** Bodies rejected because `encounter_id` is not a canonical UUID. */
const INVALID_ENCOUNTER_IDS: unknown[] = [
  undefined,
  null,
  42,
  true,
  {},
  [],
  [VALID_UUID],
  "",
  "   ",
  "not-a-uuid",
  "00000000-0000-4000-8000-00000000000",
  "00000000-0000-4000-8000-0000000000012",
  "00000000-0000-4000-8000-00000000000g",
  "000000000000400080000000000000001",
  "{00000000-0000-4000-8000-000000000001}",
  "urn:uuid:00000000-0000-4000-8000-000000000001",
  ` ${VALID_UUID}`,
  `${VALID_UUID} `,
  `${VALID_UUID}\n`,
  `${VALID_UUID}; drop table public.captures`,
];

/** Bodies rejected because `throw_quality` is not exactly one of the four contract values. */
const INVALID_THROW_QUALITIES: unknown[] = [
  undefined,
  null,
  "",
  "good",
  "Great",
  "PERFECT",
  " GOOD",
  "GOOD ",
  0,
  1,
  true,
  {},
  [],
  ["GOOD"],
];

function expectInvalid(body: Record<string, unknown>) {
  const err = assertThrows(
    () => parseResolveCaptureBody(body),
    AppError,
    undefined,
    JSON.stringify(body),
  );
  assertEquals(err.code, "INVALID_INPUT", JSON.stringify(body));
  assertEquals(err.status, 400);
}

Deno.test("resolve-capture: encounter_id must be a canonical UUID", () => {
  for (const encounter_id of INVALID_ENCOUNTER_IDS) {
    expectInvalid({ encounter_id, throw_quality: "GOOD" });
  }
  // Canonical forms accepted, either casing.
  assertEquals(
    parseResolveCaptureBody({ encounter_id: VALID_UUID, throw_quality: "MISS" }).encounterId,
    VALID_UUID,
  );
  const upper = VALID_UUID.toUpperCase();
  assertEquals(
    parseResolveCaptureBody({ encounter_id: upper, throw_quality: "MISS" }).encounterId,
    upper,
  );
});

Deno.test("resolve-capture: throw_quality must be one of the four contract values", () => {
  for (const throw_quality of INVALID_THROW_QUALITIES) {
    expectInvalid({ encounter_id: VALID_UUID, throw_quality });
  }
  for (const quality of ["MISS", "GOOD", "GREAT", "EXCELLENT"] as const) {
    assertEquals(
      parseResolveCaptureBody({ encounter_id: VALID_UUID, throw_quality: quality }).throwQuality,
      quality,
    );
  }
  // Unknown extra fields are ignored, not rejected.
  assertEquals(
    parseResolveCaptureBody({ encounter_id: VALID_UUID, throw_quality: "GOOD", p_roll: 0 }),
    { encounterId: VALID_UUID, throwQuality: "GOOD" },
  );
});

Deno.test("resolve-capture http: invalid fields -> 400 INVALID_INPUT, RPC never called", async () => {
  const db = seededDb();
  let rpcCalls = 0;
  const spy: Db = {
    from: <T extends Row = Row>(table: string) => db.from<T>(table),
    rpc: (fn: string, args?: Record<string, unknown>) => {
      rpcCalls++;
      return db.rpc(fn, args);
    },
  };
  const handler = createHttpHandler({ db: spy, random: () => 0, auth: fakeAuth() });
  const bodies: Record<string, unknown>[] = [
    {},
    { encounter_id: "not-a-uuid", throw_quality: "GOOD" },
    { encounter_id: VALID_UUID },
    { encounter_id: VALID_UUID, throw_quality: "good" },
    { encounter_id: null, throw_quality: "GOOD" },
    { encounter_id: VALID_UUID, throw_quality: null },
    { encounter_id: [VALID_UUID], throw_quality: "GOOD" },
  ];
  for (const body of bodies) {
    await expectErrorResponse(
      await handler(postJson("resolve-capture", body, PLAYER_TOKEN)),
      400,
      "INVALID_INPUT",
    );
  }
  assertEquals(rpcCalls, 0);
});

Deno.test("resolve-capture http: an oversized body -> 400 INVALID_INPUT", async () => {
  const db = seededDb();
  const enc = activeEncounter(db);
  const huge = JSON.stringify({
    encounter_id: enc.id,
    throw_quality: "EXCELLENT",
    padding: "x".repeat(MAX_BODY_BYTES),
  });
  await expectErrorResponse(
    await httpHandler(db, 0)(postJson("resolve-capture", huge, PLAYER_TOKEN)),
    400,
    "INVALID_INPUT",
  );
  assertEquals(db.rows("captures").length, 0);
});
