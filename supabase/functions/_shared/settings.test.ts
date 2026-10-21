import { assertEquals } from "@std/assert";
import { loadAppSettings } from "./settings.ts";
import { FakeDb } from "./testing/fake_db.ts";

function dbWith(value: unknown): FakeDb {
  const db = new FakeDb();
  db.seed("app_settings", [{ key: "encounter_expiration_seconds", value }]);
  return db;
}

Deno.test("loadAppSettings: reads a numeric jsonb value (and numeric strings)", async () => {
  assertEquals((await loadAppSettings(dbWith(240))).encounterExpirationSeconds, 240);
  assertEquals((await loadAppSettings(dbWith("90"))).encounterExpirationSeconds, 90);
  assertEquals((await loadAppSettings(dbWith(59.9))).encounterExpirationSeconds, 59);
});

Deno.test("loadAppSettings: falls back to 180 when missing or invalid", async () => {
  assertEquals((await loadAppSettings(new FakeDb())).encounterExpirationSeconds, 180);
  for (const bad of [0, -5, "abc", null, { seconds: 10 }]) {
    assertEquals((await loadAppSettings(dbWith(bad))).encounterExpirationSeconds, 180);
  }
});
