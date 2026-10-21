import { assertEquals, assertThrows } from "@std/assert";
import { AppError } from "./errors.ts";
import {
  MAX_TAG_IDENTIFIER_LENGTH,
  parseOptionalBoolean,
  parseOptionalUuid,
  parseTagIdentifier,
  parseThrowQuality,
  parseUuid,
} from "./validate.ts";

/** Asserts the call throws INVALID_INPUT and returns the (non-empty) user-facing message. */
function rejects(fn: () => unknown, label: string): string {
  const err = assertThrows(fn, AppError, undefined, label);
  assertEquals(err.code, "INVALID_INPUT", label);
  assertEquals(err.status, 400, label);
  assertEquals(err.message.length > 0, true, label);
  return err.message;
}

Deno.test("parseTagIdentifier: rejects every non-string type", () => {
  for (
    const raw of [undefined, null, 42, 0, true, false, {}, [], ["A"], { tag: "A" }, 1.5, NaN]
  ) {
    rejects(() => parseTagIdentifier(raw), `non-string ${JSON.stringify(raw) ?? String(raw)}`);
  }
});

Deno.test("parseTagIdentifier: rejects empty and whitespace-only strings", () => {
  for (const raw of ["", " ", "   ", "\t", "\n", " \t\n "]) {
    rejects(() => parseTagIdentifier(raw), `blank ${JSON.stringify(raw)}`);
  }
});

Deno.test("parseTagIdentifier: trims and accepts up to MAX_TAG_IDENTIFIER_LENGTH chars", () => {
  assertEquals(parseTagIdentifier("DEMO-TAG-01"), "DEMO-TAG-01");
  assertEquals(parseTagIdentifier("  DEMO-TAG-01  "), "DEMO-TAG-01");
  assertEquals(parseTagIdentifier("\tDEMO-TAG-01\n"), "DEMO-TAG-01");
  assertEquals(MAX_TAG_IDENTIFIER_LENGTH, 128);

  const atLimit = "x".repeat(MAX_TAG_IDENTIFIER_LENGTH);
  assertEquals(parseTagIdentifier(atLimit), atLimit);
  // The length is measured after trimming: padding does not count towards the cap.
  assertEquals(parseTagIdentifier(`   ${atLimit}   `), atLimit);
});

Deno.test("parseTagIdentifier: rejects anything longer than the cap", () => {
  for (const length of [MAX_TAG_IDENTIFIER_LENGTH + 1, MAX_TAG_IDENTIFIER_LENGTH * 10, 10_000]) {
    const msg = rejects(() => parseTagIdentifier("x".repeat(length)), `length ${length}`);
    assertEquals(msg.includes(String(MAX_TAG_IDENTIFIER_LENGTH)), true, msg);
  }
});

Deno.test("parseTagIdentifier: rejects control characters (NUL, newline, DEL, C1)", () => {
  const controls = ["\u0000", "\n", "\r", "\t", "\u001f", "\u007f", "\u009f"];
  for (const ch of controls) {
    const raw = `TAG${ch}01`;
    rejects(() => parseTagIdentifier(raw), `control char U+${ch.charCodeAt(0).toString(16)}`);
  }
  // Non-ASCII printable characters are fine (tags may be labelled in Spanish).
  assertEquals(parseTagIdentifier("AULA-N-01"), "AULA-N-01");
  assertEquals(parseTagIdentifier("AULA-\u00d1-01"), "AULA-\u00d1-01");
});

Deno.test("parseTagIdentifier: the field name appears in the message", () => {
  const msg = rejects(() => parseTagIdentifier(42, "tag_identifier"), "named field");
  assertEquals(msg.includes("tag_identifier"), true, msg);
});

Deno.test("parseUuid: accepts canonical UUIDs only", () => {
  const id = crypto.randomUUID();
  assertEquals(parseUuid(id, "encounter_id"), id);
  assertEquals(
    parseUuid("00000000-0000-4000-8000-000000000001", "encounter_id"),
    "00000000-0000-4000-8000-000000000001",
  );
  // Case-insensitive: Postgres accepts either casing for uuid literals.
  assertEquals(
    parseUuid("00000000-0000-4000-8000-00000000000A", "encounter_id"),
    "00000000-0000-4000-8000-00000000000A",
  );
});

Deno.test("parseUuid: rejects non-strings and malformed UUIDs", () => {
  const bad: unknown[] = [
    undefined,
    null,
    42,
    true,
    {},
    [],
    ["00000000-0000-4000-8000-000000000001"],
    "",
    "   ",
    "not-a-uuid",
    "00000000-0000-4000-8000-00000000000", // one char short
    "00000000-0000-4000-8000-0000000000012", // one char long
    "00000000-0000-4000-8000-00000000000g", // non-hex
    "000000000000400080000000000000001", // no dashes
    "{00000000-0000-4000-8000-000000000001}", // braced form
    "urn:uuid:00000000-0000-4000-8000-000000000001",
    " 00000000-0000-4000-8000-000000000001", // leading space
    "00000000-0000-4000-8000-000000000001 ", // trailing space
    "00000000-0000-4000-8000-000000000001\n", // trailing newline
    "00000000-0000-4000-8000-000000000001' or '1'='1", // injection-ish suffix
  ];
  for (const raw of bad) {
    const msg = rejects(() => parseUuid(raw, "encounter_id"), `uuid ${String(raw)}`);
    assertEquals(msg.includes("encounter_id"), true, msg);
  }
});

Deno.test("parseOptionalUuid: undefined and null mean 'no value'", () => {
  assertEquals(parseOptionalUuid(undefined, "professor_id"), null);
  assertEquals(parseOptionalUuid(null, "professor_id"), null);
  const id = crypto.randomUUID();
  assertEquals(parseOptionalUuid(id, "professor_id"), id);
});

Deno.test("parseOptionalUuid: rejects a present but invalid value", () => {
  for (const raw of ["", "nope", 42, true, {}, [], "00000000-0000-4000-8000-00000000000"]) {
    const msg = rejects(() => parseOptionalUuid(raw, "professor_id"), `optional uuid ${raw}`);
    assertEquals(msg.includes("professor_id"), true, msg);
  }
});

Deno.test("parseThrowQuality: accepts the four contract values, case-sensitively", () => {
  for (const q of ["MISS", "GOOD", "GREAT", "EXCELLENT"] as const) {
    assertEquals(parseThrowQuality(q), q);
  }
  const bad: unknown[] = [
    "good",
    "Great",
    "PERFECT",
    "",
    " GOOD",
    "GOOD ",
    0,
    1,
    null,
    undefined,
    true,
    {},
    [],
    ["GOOD"],
  ];
  for (const raw of bad) {
    rejects(() => parseThrowQuality(raw), `quality ${String(raw)}`);
  }
});

Deno.test("parseOptionalBoolean: only a missing key falls back to the default", () => {
  assertEquals(parseOptionalBoolean(undefined, "active", true), true);
  assertEquals(parseOptionalBoolean(undefined, "active", false), false);
  assertEquals(parseOptionalBoolean(true, "active", false), true);
  assertEquals(parseOptionalBoolean(false, "active", true), false);
  for (const raw of [null, "true", "false", "yes", 0, 1, {}, []]) {
    const msg = rejects(() => parseOptionalBoolean(raw, "active", true), `boolean ${String(raw)}`);
    assertEquals(msg.includes("active"), true, msg);
  }
});
