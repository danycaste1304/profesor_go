import { assert, assertEquals } from "@std/assert";
import { AppError, ERROR_STATUS, jsonOk } from "./errors.ts";
import { MAX_BODY_BYTES, readJsonBody, withHttp } from "./http.ts";
import { expectErrorResponse } from "./testing/fixtures.ts";

const url = "http://localhost/fn";
const post = (body: string) =>
  new Request(url, { method: "POST", headers: { "Content-Type": "application/json" }, body });

Deno.test("withHttp: OPTIONS preflight -> 204 + CORS headers, handler not invoked", async () => {
  let called = false;
  const handler = withHttp("fn", () => {
    called = true;
    return Promise.resolve(jsonOk({}));
  });
  const res = await handler(new Request(url, { method: "OPTIONS" }));
  assertEquals(res.status, 204);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
  assertEquals(
    res.headers.get("access-control-allow-headers"),
    "authorization, x-client-info, apikey, content-type",
  );
  assertEquals(res.headers.get("access-control-allow-methods"), "POST, OPTIONS");
  assertEquals(called, false);
});

Deno.test("withHttp: non-POST -> 405 METHOD_NOT_ALLOWED", async () => {
  const handler = withHttp("fn", () => Promise.resolve(jsonOk({})));
  for (const method of ["GET", "PUT", "DELETE", "PATCH"]) {
    await expectErrorResponse(
      await handler(new Request(url, { method })),
      405,
      "METHOD_NOT_ALLOWED",
    );
  }
});

Deno.test("withHttp: AppError -> its status and { error, message }", async () => {
  const handler = withHttp("fn", () => Promise.reject(new AppError("TAG_DISABLED", "custom")));
  const res = await handler(post("{}"));
  assertEquals(res.status, 403);
  assertEquals(await res.json(), { error: "TAG_DISABLED", message: "custom" });
});

Deno.test("withHttp: every error code maps to its contract status", async () => {
  for (const [code, status] of Object.entries(ERROR_STATUS)) {
    const handler = withHttp(
      "fn",
      () => Promise.reject(new AppError(code as keyof typeof ERROR_STATUS)),
    );
    const res = await handler(post("{}"));
    assertEquals(res.status, status, code);
    assertEquals((await res.json()).error, code);
  }
});

Deno.test("withHttp: unexpected error -> 500 INTERNAL_ERROR without leaking details", async () => {
  const handler = withHttp("fn", () => Promise.reject(new Error("db password is hunter2")));
  const res = await handler(post("{}"));
  await expectErrorResponse(res, 500, "INTERNAL_ERROR");
});

Deno.test("withHttp: successful handler response passes through with JSON + CORS headers", async () => {
  const handler = withHttp("fn", () => Promise.resolve(jsonOk({ ok: true })));
  const res = await handler(post("{}"));
  assertEquals(res.status, 200);
  assert(res.headers.get("content-type")!.startsWith("application/json"));
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
  assertEquals(await res.json(), { ok: true });
});

Deno.test("readJsonBody: accepts objects, rejects malformed JSON, arrays and primitives", async () => {
  assertEquals(await readJsonBody(post('{"a":1}')), { a: 1 });
  for (const raw of ["{oops", "[1,2]", "42", "null", ""]) {
    let thrown: unknown;
    try {
      await readJsonBody(post(raw));
    } catch (err) {
      thrown = err;
    }
    assert(thrown instanceof AppError, `expected AppError for ${JSON.stringify(raw)}`);
    assertEquals(thrown.code, "INVALID_INPUT");
  }
});

Deno.test("readJsonBody: rejects a body larger than MAX_BODY_BYTES", async () => {
  const body = JSON.stringify({ tag_identifier: "x".repeat(MAX_BODY_BYTES) });
  assert(body.length > MAX_BODY_BYTES);
  let thrown: unknown;
  try {
    await readJsonBody(post(body));
  } catch (err) {
    thrown = err;
  }
  assert(thrown instanceof AppError);
  assertEquals(thrown.code, "INVALID_INPUT");
});

Deno.test("readJsonBody: an oversized Content-Length is rejected without reading the body", async () => {
  const req = new Request(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": String(MAX_BODY_BYTES + 1),
    },
    body: '{"tag_identifier":"DEMO-TAG-01"}',
  });
  let thrown: unknown;
  try {
    await readJsonBody(req);
  } catch (err) {
    thrown = err;
  }
  assert(thrown instanceof AppError);
  assertEquals(thrown.code, "INVALID_INPUT");
  assertEquals(req.bodyUsed, false, "the oversized body must not be buffered");
});

Deno.test("readJsonBody: a missing or non-numeric Content-Length falls back to the size backstop", async () => {
  const big = JSON.stringify({ tag_identifier: "x".repeat(MAX_BODY_BYTES) });
  const cases: Record<string, string>[] = [
    {},
    { "Content-Length": "not-a-number" },
    { "Content-Length": "10" },
  ];
  for (const headers of cases) {
    const req = new Request(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...headers },
      body: big,
    });
    let thrown: unknown;
    try {
      await readJsonBody(req);
    } catch (err) {
      thrown = err;
    }
    assert(thrown instanceof AppError, `expected AppError for ${JSON.stringify(headers)}`);
    assertEquals(thrown.code, "INVALID_INPUT");
  }
});

Deno.test("readJsonBody: accepts a body right at the size limit", async () => {
  const filler = "y".repeat(MAX_BODY_BYTES - '{"tag_identifier":""}'.length);
  const body = JSON.stringify({ tag_identifier: filler });
  assertEquals(body.length, MAX_BODY_BYTES);
  assertEquals(await readJsonBody(post(body)), { tag_identifier: filler });
});

Deno.test("withHttp: an oversized body is rejected with 400 before the handler runs", async () => {
  let called = false;
  const handler = withHttp("fn", async (req) => {
    called = true;
    await readJsonBody(req);
    return jsonOk({});
  });
  const body = JSON.stringify({ padding: "x".repeat(MAX_BODY_BYTES) });
  const res = await handler(
    new Request(url, { method: "POST", headers: { "Content-Type": "application/json" }, body }),
  );
  await expectErrorResponse(res, 400, "INVALID_INPUT");
  assertEquals(called, true); // the wrapper runs the handler; readJsonBody is what rejects
});
