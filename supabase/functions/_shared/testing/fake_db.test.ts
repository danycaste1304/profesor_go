import { assertEquals } from "@std/assert";
import { FakeDb } from "./fake_db.ts";

Deno.test("FakeDb: select/eq/maybeSingle/single and column projection", async () => {
  const db = new FakeDb();
  db.seed("professors", [{
    id: "p1",
    name: "A",
    display_name: "Prof. A",
    rarity: "COMMON",
    base_capture_rate: 0.8,
  }]);

  const one = await db.from("professors").select("id, active").eq("id", "p1").maybeSingle();
  assertEquals(one, { data: { id: "p1", active: true }, error: null });

  const none = await db.from("professors").select().eq("id", "nope").maybeSingle();
  assertEquals(none, { data: null, error: null });

  const single = await db.from("professors").select("id").eq("id", "nope").single();
  assertEquals(single.data, null);
  assertEquals(single.error?.code, "PGRST116");

  const all = await db.from("professors").select("id");
  assertEquals(all, { data: [{ id: "p1" }], error: null });
});

Deno.test("FakeDb: insert fills defaults, enforces unique keys; update + upsert mutate in place", async () => {
  const db = new FakeDb(() => new Date("2026-01-01T00:00:00.000Z"));

  const inserted = await db.from("captures").insert({
    user_id: "u",
    professor_id: "p",
    throw_quality: "GOOD",
  })
    .select("id, user_id, encounter_id, captured_at").single();
  assertEquals(inserted.error, null);
  assertEquals(inserted.data?.encounter_id, null);
  assertEquals(inserted.data?.captured_at, "2026-01-01T00:00:00.000Z");

  const dup = await db.from("captures").insert({
    user_id: "u",
    professor_id: "p",
    throw_quality: "GOOD",
  });
  assertEquals(dup.error?.code, "23505");

  db.seed("encounters", [{
    id: "e1",
    user_id: "u",
    professor_id: "p",
    expires_at: "x",
    status: "ACTIVE",
  }]);
  const updated = await db.from("encounters").update({ status: "EXPIRED" }).eq("user_id", "u").eq(
    "status",
    "ACTIVE",
  );
  assertEquals(updated, { data: null, error: null });
  assertEquals(db.rows("encounters")[0].status, "EXPIRED");

  const first = await db.from("nfc_tags").upsert({ tag_identifier: "T", professor_id: "p" }, {
    onConflict: "tag_identifier",
  })
    .select("id, professor_id").single();
  const second = await db.from("nfc_tags").upsert({ tag_identifier: "T", professor_id: null }, {
    onConflict: "tag_identifier",
  })
    .select("id, professor_id").single();
  assertEquals(first.data?.id, second.data?.id);
  assertEquals(second.data?.professor_id, null);
  assertEquals(db.rows("nfc_tags").length, 1);
});

Deno.test("FakeDb: unknown rpc returns an error result", async () => {
  const res = await new FakeDb().rpc("nope");
  assertEquals(res.data, null);
  assertEquals(res.error?.code, "42883");
});
