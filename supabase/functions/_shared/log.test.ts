import { assert, assertEquals } from "@std/assert";
import { logEvent, redact, setLogSink } from "./log.ts";

const JWT = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.sflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c";

Deno.test("redact: hides secret-looking keys and JWT-looking values", () => {
  const out = redact({
    user_id: "u1",
    authorization: "Bearer x",
    access_token: "abc",
    SUPABASE_SERVICE_ROLE_KEY: "svc",
    apiKey: "k",
    note: JWT,
    count: 3,
  });
  assertEquals(out, {
    user_id: "u1",
    authorization: "[redacted]",
    access_token: "[redacted]",
    SUPABASE_SERVICE_ROLE_KEY: "[redacted]",
    apiKey: "[redacted]",
    note: "[redacted]",
    count: 3,
  });
});

Deno.test("logEvent: emits one JSON line with ts + event and redacted fields", () => {
  const lines: string[] = [];
  setLogSink((line) => lines.push(line));
  try {
    logEvent("encounter_started", { user_id: "u1", jwt: JWT });
  } finally {
    setLogSink(() => {});
  }
  assertEquals(lines.length, 1);
  const parsed = JSON.parse(lines[0]);
  assertEquals(parsed.event, "encounter_started");
  assertEquals(parsed.user_id, "u1");
  assertEquals(parsed.jwt, "[redacted]");
  assert(!lines[0].includes(JWT));
  assert(!Number.isNaN(Date.parse(parsed.ts)));
});
