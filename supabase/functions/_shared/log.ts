/** Structured, single-line JSON logging. Never logs secrets or JWTs (see `redact`). */

export type LogEvent =
  | "encounter_started"
  | "capture_resolved"
  | "invalid_tag"
  | "professor_disabled"
  | "duplicate_capture"
  | "encounter_not_found"
  | "encounter_not_active"
  | "encounter_expired"
  | "forbidden"
  | "unauthorized"
  | "invalid_input"
  | "nfc_tag_registered"
  | "professor_not_found"
  | "db_error"
  | "internal_error";

type LogSink = (line: string) => void;

const defaultSink: LogSink = (line) => console.log(line);
let sink: LogSink = defaultSink;

/** Replaces the output sink (tests pass a no-op or a collector). `null` restores console.log. */
export function setLogSink(next: LogSink | null): void {
  sink = next ?? defaultSink;
}

const SECRET_KEY_RE = /authorization|token|jwt|secret|password|api[_-]?key|service[_-]?role/i;
const JWT_VALUE_RE = /^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$/;

/** Drops values whose key looks secret and any value that looks like a JWT. */
export function redact(fields: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    if (SECRET_KEY_RE.test(key)) {
      out[key] = "[redacted]";
    } else if (typeof value === "string" && JWT_VALUE_RE.test(value)) {
      out[key] = "[redacted]";
    } else {
      out[key] = value;
    }
  }
  return out;
}

export function logEvent(event: LogEvent, fields: Record<string, unknown> = {}): void {
  sink(JSON.stringify({ ts: new Date().toISOString(), event, ...redact(fields) }));
}
