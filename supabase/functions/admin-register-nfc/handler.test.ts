import { assert, assertEquals, assertThrows } from "@std/assert";
import { AppError } from "../_shared/errors.ts";
import { MAX_BODY_BYTES } from "../_shared/http.ts";
import { FakeDb } from "../_shared/testing/fake_db.ts";
import {
  ADMIN_ID,
  ADMIN_TOKEN,
  expectAppError,
  expectErrorResponse,
  fakeAuth,
  FIXED_NOW,
  PLAYER_ID,
  PLAYER_TOKEN,
  postJson,
  PROF_COMMON_ID,
  PROF_RARE_ID,
  seededDb,
  TAG_COMMON,
} from "../_shared/testing/fixtures.ts";
import { isUuid } from "../_shared/types.ts";
import { createHttpHandler, handleAdminRegisterNfc, parseAdminRegisterNfcBody } from "./handler.ts";

const MISSING_PROFESSOR = "00000000-0000-4000-8000-0000000000ff";

// ---------------------------------------------------------------- pure handler

Deno.test("admin-register-nfc: non-admin caller -> FORBIDDEN (403), nothing written", async () => {
  const db = seededDb();
  const before = db.rows("nfc_tags").length;
  await expectAppError(
    () =>
      handleAdminRegisterNfc({ db }, {
        userId: PLAYER_ID,
        tagIdentifier: "NEW-TAG",
        professorId: PROF_COMMON_ID,
        active: true,
      }),
    "FORBIDDEN",
    403,
  );
  assertEquals(db.rows("nfc_tags").length, before);
});

Deno.test("admin-register-nfc: unknown caller profile -> FORBIDDEN (403)", async () => {
  await expectAppError(
    () =>
      handleAdminRegisterNfc({ db: seededDb() }, {
        userId: "44444444-4444-4444-8444-444444444444",
        tagIdentifier: "NEW-TAG",
        professorId: null,
        active: true,
      }),
    "FORBIDDEN",
    403,
  );
});

Deno.test("admin-register-nfc: inserts a new tag and then updates it by tag_identifier (upsert)", async () => {
  const db = seededDb();
  const before = db.rows("nfc_tags").length;

  const created = await handleAdminRegisterNfc({ db }, {
    userId: ADMIN_ID,
    tagIdentifier: "NEW-TAG-42",
    professorId: PROF_COMMON_ID,
    active: true,
  });
  assertEquals(Object.keys(created.tag).sort(), [
    "active",
    "created_at",
    "id",
    "professor_id",
    "tag_identifier",
  ]);
  assert(isUuid(created.tag.id));
  assertEquals(created.tag.tag_identifier, "NEW-TAG-42");
  assertEquals(created.tag.professor_id, PROF_COMMON_ID);
  assertEquals(created.tag.active, true);
  assertEquals(created.tag.created_at, FIXED_NOW.toISOString());
  assertEquals(db.rows("nfc_tags").length, before + 1);

  const updated = await handleAdminRegisterNfc({ db }, {
    userId: ADMIN_ID,
    tagIdentifier: "NEW-TAG-42",
    professorId: PROF_RARE_ID,
    active: false,
  });
  assertEquals(updated.tag.id, created.tag.id);
  assertEquals(updated.tag.professor_id, PROF_RARE_ID);
  assertEquals(updated.tag.active, false);
  assertEquals(updated.tag.created_at, created.tag.created_at);
  assertEquals(db.rows("nfc_tags").length, before + 1);
});

Deno.test("admin-register-nfc: professor_id null unassigns the tag", async () => {
  const db = seededDb();
  const result = await handleAdminRegisterNfc({ db }, {
    userId: ADMIN_ID,
    tagIdentifier: TAG_COMMON,
    professorId: null,
    active: true,
  });
  assertEquals(result.tag.professor_id, null);
  const stored = db.rows("nfc_tags").find((t) => t.tag_identifier === TAG_COMMON)!;
  assertEquals(stored.professor_id, null);
});

Deno.test("admin-register-nfc: unknown professor -> PROFESSOR_NOT_FOUND (404), nothing written", async () => {
  const db = seededDb();
  const before = db.rows("nfc_tags").length;
  await expectAppError(
    () =>
      handleAdminRegisterNfc({ db }, {
        userId: ADMIN_ID,
        tagIdentifier: "NEW-TAG",
        professorId: MISSING_PROFESSOR,
        active: true,
      }),
    "PROFESSOR_NOT_FOUND",
    404,
  );
  assertEquals(db.rows("nfc_tags").length, before);
});

// ---------------------------------------------------------------- input validation

Deno.test("admin-register-nfc: body validation", () => {
  const reject = (body: Record<string, unknown>) => {
    let thrown: unknown;
    try {
      parseAdminRegisterNfcBody(body);
    } catch (err) {
      thrown = err;
    }
    assert(thrown instanceof AppError, `expected AppError for ${JSON.stringify(body)}`);
    assertEquals(thrown.code, "INVALID_INPUT");
  };
  reject({});
  reject({ tag_identifier: "   " });
  reject({ tag_identifier: 42 });
  reject({ tag_identifier: "T", professor_id: "nope" });
  reject({ tag_identifier: "T", active: "yes" });
  reject({ tag_identifier: "x".repeat(129) });

  assertEquals(parseAdminRegisterNfcBody({ tag_identifier: " T-1 " }), {
    tagIdentifier: "T-1",
    professorId: null,
    active: true,
  });
  assertEquals(
    parseAdminRegisterNfcBody({
      tag_identifier: "T-1",
      professor_id: PROF_COMMON_ID,
      active: false,
    }),
    { tagIdentifier: "T-1", professorId: PROF_COMMON_ID, active: false },
  );
  assertEquals(
    parseAdminRegisterNfcBody({ tag_identifier: "T-1", professor_id: null }).professorId,
    null,
  );
});

// ---------------------------------------------------------------- HTTP adapter

function httpHandler(db: FakeDb = seededDb()) {
  return createHttpHandler({ db, auth: fakeAuth() });
}

Deno.test("admin-register-nfc http: status mapping", async () => {
  const db = seededDb();
  const handler = httpHandler(db);
  const body = { tag_identifier: "HTTP-TAG", professor_id: PROF_COMMON_ID, active: true };

  await expectErrorResponse(
    await handler(postJson("admin-register-nfc", body)),
    401,
    "UNAUTHORIZED",
  );
  await expectErrorResponse(
    await handler(postJson("admin-register-nfc", body, PLAYER_TOKEN)),
    403,
    "FORBIDDEN",
  );
  await expectErrorResponse(
    await handler(postJson("admin-register-nfc", { professor_id: PROF_COMMON_ID }, ADMIN_TOKEN)),
    400,
    "INVALID_INPUT",
  );
  await expectErrorResponse(
    await handler(
      postJson("admin-register-nfc", { ...body, professor_id: MISSING_PROFESSOR }, ADMIN_TOKEN),
    ),
    404,
    "PROFESSOR_NOT_FOUND",
  );

  const ok = await handler(postJson("admin-register-nfc", body, ADMIN_TOKEN));
  assertEquals(ok.status, 200);
  const json = await ok.json();
  assertEquals(Object.keys(json), ["tag"]);
  assertEquals(Object.keys(json.tag).sort(), [
    "active",
    "created_at",
    "id",
    "professor_id",
    "tag_identifier",
  ]);
  assertEquals(json.tag.tag_identifier, "HTTP-TAG");
  assertEquals(json.tag.professor_id, PROF_COMMON_ID);
});

Deno.test("admin-register-nfc http: OPTIONS preflight -> 204", async () => {
  const res = await httpHandler()(
    postJson("admin-register-nfc", "", undefined, { method: "OPTIONS" }),
  );
  assertEquals(res.status, 204);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
});

// ------------------------------------------------- input validation (field by field)

function expectInvalidBody(body: Record<string, unknown>) {
  const err = assertThrows(
    () => parseAdminRegisterNfcBody(body),
    AppError,
    undefined,
    JSON.stringify(body),
  );
  assertEquals(err.code, "INVALID_INPUT", JSON.stringify(body));
  assertEquals(err.status, 400);
}

Deno.test("admin-register-nfc: tag_identifier type / trim / length / control chars", () => {
  for (
    const tag_identifier of [
      undefined,
      null,
      42,
      true,
      {},
      [],
      ["T"],
      "",
      "   ",
      "\t\n",
      "x".repeat(129),
      `  ${"x".repeat(129)}  `,
      "TAG\u0000-01",
      "TAG\n01",
      "TAG\u009f01",
    ]
  ) {
    expectInvalidBody({ tag_identifier });
  }
  const atLimit = "x".repeat(128);
  assertEquals(parseAdminRegisterNfcBody({ tag_identifier: atLimit }).tagIdentifier, atLimit);
  assertEquals(
    parseAdminRegisterNfcBody({ tag_identifier: `  ${atLimit}  ` }).tagIdentifier,
    atLimit,
  );
  assertEquals(
    parseAdminRegisterNfcBody({ tag_identifier: "AULA-Ñ-01" }).tagIdentifier,
    "AULA-Ñ-01",
  );
});

Deno.test("admin-register-nfc: professor_id must be a UUID or null", () => {
  for (
    const professor_id of [
      "nope",
      "",
      "   ",
      42,
      true,
      {},
      [],
      [PROF_COMMON_ID],
      "00000000-0000-4000-8000-00000000000",
      "{00000000-0000-4000-8000-000000000001}",
      ` ${PROF_COMMON_ID}`,
    ]
  ) {
    expectInvalidBody({ tag_identifier: "T-1", professor_id });
  }
  assertEquals(
    parseAdminRegisterNfcBody({ tag_identifier: "T-1", professor_id: null }).professorId,
    null,
  );
  assertEquals(parseAdminRegisterNfcBody({ tag_identifier: "T-1" }).professorId, null);
  assertEquals(
    parseAdminRegisterNfcBody({ tag_identifier: "T-1", professor_id: PROF_COMMON_ID }).professorId,
    PROF_COMMON_ID,
  );
});

Deno.test("admin-register-nfc: active must be a boolean when present (default true)", () => {
  for (const active of [null, "true", "false", "yes", 0, 1, {}, []]) {
    expectInvalidBody({ tag_identifier: "T-1", active });
  }
  assertEquals(parseAdminRegisterNfcBody({ tag_identifier: "T-1" }).active, true);
  assertEquals(parseAdminRegisterNfcBody({ tag_identifier: "T-1", active: true }).active, true);
  assertEquals(parseAdminRegisterNfcBody({ tag_identifier: "T-1", active: false }).active, false);
  // Unknown extra fields are ignored, not rejected.
  assertEquals(parseAdminRegisterNfcBody({ tag_identifier: "T-1", id: "x" }), {
    tagIdentifier: "T-1",
    professorId: null,
    active: true,
  });
});

Deno.test("admin-register-nfc http: invalid fields -> 400 INVALID_INPUT, nothing written", async () => {
  const db = seededDb();
  const handler = httpHandler(db);
  const before = db.rows("nfc_tags").length;
  const bodies: Record<string, unknown>[] = [
    {},
    { tag_identifier: "  " },
    { tag_identifier: 42 },
    { tag_identifier: "x".repeat(129) },
    { tag_identifier: "TAG\u0000" },
    { tag_identifier: "T-1", professor_id: "nope" },
    { tag_identifier: "T-1", active: "yes" },
    { tag_identifier: "T-1", active: null },
  ];
  for (const body of bodies) {
    await expectErrorResponse(
      await handler(postJson("admin-register-nfc", body, ADMIN_TOKEN)),
      400,
      "INVALID_INPUT",
    );
  }
  assertEquals(db.rows("nfc_tags").length, before);
});

Deno.test("admin-register-nfc http: an oversized body -> 400 INVALID_INPUT", async () => {
  const db = seededDb();
  const before = db.rows("nfc_tags").length;
  const huge = JSON.stringify({
    tag_identifier: "TAG-HUGE",
    professor_id: PROF_COMMON_ID,
    padding: "x".repeat(MAX_BODY_BYTES),
  });
  await expectErrorResponse(
    await httpHandler(db)(postJson("admin-register-nfc", huge, ADMIN_TOKEN)),
    400,
    "INVALID_INPUT",
  );
  assertEquals(db.rows("nfc_tags").length, before);
});
