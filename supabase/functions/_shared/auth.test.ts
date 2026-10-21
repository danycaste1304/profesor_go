import { assertEquals } from "@std/assert";
import { extractBearerToken, getUserFromRequest } from "./auth.ts";
import { expectAppError, fakeAuth, PLAYER_ID, PLAYER_TOKEN, postJson } from "./testing/fixtures.ts";

Deno.test("extractBearerToken: parses the Bearer scheme case-insensitively", () => {
  assertEquals(
    extractBearerToken(new Headers({ Authorization: "Bearer abc.def.ghi" })),
    "abc.def.ghi",
  );
  assertEquals(extractBearerToken(new Headers({ authorization: "bearer   xyz" })), "xyz");
});

Deno.test("extractBearerToken: missing or malformed header -> UNAUTHORIZED", async () => {
  const cases: Record<string, string>[] = [
    {},
    { Authorization: "" },
    { Authorization: "Basic abc" },
    { Authorization: "Bearer" },
  ];
  for (const headers of cases) {
    await expectAppError(
      () => Promise.resolve().then(() => extractBearerToken(new Headers(headers))),
      "UNAUTHORIZED",
      401,
    );
  }
});

Deno.test("getUserFromRequest: valid JWT -> { id, email }", async () => {
  const user = await getUserFromRequest(postJson("fn", {}, PLAYER_TOKEN), fakeAuth());
  assertEquals(user, { id: PLAYER_ID, email: "player@profesorgo.local" });
});

Deno.test("getUserFromRequest: email is null when GoTrue omits it", async () => {
  const auth = {
    getUser: () => Promise.resolve({ data: { user: { id: "u1" } }, error: null }),
  };
  assertEquals(await getUserFromRequest(postJson("fn", {}, "t"), auth), { id: "u1", email: null });
});

Deno.test("getUserFromRequest: rejected JWT or missing header -> UNAUTHORIZED", async () => {
  await expectAppError(
    () => getUserFromRequest(postJson("fn", {}, "bad"), fakeAuth()),
    "UNAUTHORIZED",
    401,
  );
  await expectAppError(
    () => getUserFromRequest(postJson("fn", {}), fakeAuth()),
    "UNAUTHORIZED",
    401,
  );
});
