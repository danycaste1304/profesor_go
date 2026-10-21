import { assertEquals } from "@std/assert";
import {
  isEncounterStatus,
  isNonEmptyString,
  isRarity,
  isRole,
  isThrowQuality,
  isUuid,
} from "./types.ts";

Deno.test("enum validators accept contract values only (case-sensitive)", () => {
  assertEquals(["COMMON", "RARE", "EPIC", "LEGENDARY"].every(isRarity), true);
  assertEquals(isRarity("common"), false);
  assertEquals(["MISS", "GOOD", "GREAT", "EXCELLENT"].every(isThrowQuality), true);
  assertEquals(isThrowQuality("PERFECT"), false);
  assertEquals(["ACTIVE", "SUCCESS", "FAILED", "EXPIRED"].every(isEncounterStatus), true);
  assertEquals(isEncounterStatus(null), false);
  assertEquals(isRole("admin"), true);
  assertEquals(isRole("root"), false);
});

Deno.test("isUuid / isNonEmptyString", () => {
  assertEquals(isUuid("00000000-0000-4000-8000-000000000001"), true);
  assertEquals(isUuid(crypto.randomUUID()), true);
  assertEquals(isUuid("00000000-0000-4000-8000-00000000000"), false);
  assertEquals(isUuid(42), false);
  assertEquals(isNonEmptyString("a"), true);
  assertEquals(isNonEmptyString("  "), false);
  assertEquals(isNonEmptyString(undefined), false);
});
