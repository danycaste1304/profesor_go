# Edge Functions — Profesor GO

Deno Edge Functions that implement the write path of the game (CONTRACTS §4, §9, §10):

| Function             | Purpose                                                                   |
| -------------------- | ------------------------------------------------------------------------- |
| `start-encounter`    | NFC tag scanned → validates tag/professor → creates an `ACTIVE` encounter |
| `resolve-capture`    | Throw made → calls the atomic RPC `resolve_capture_tx` → success/failure  |
| `admin-register-nfc` | Admin only → upserts an `nfc_tags` row by `tag_identifier`                |

All functions are `POST` + `Authorization: Bearer <user JWT>` + JSON body, and answer JSON. Errors
are `4xx/5xx` with `{ "error": "<CODE>", "message": "<texto legible>" }`.

Layout:

```
supabase/functions/
├── deno.json                 # import map + tasks (check / test / lint / fmt)
├── _shared/                  # cors, errors, http, auth, db (typed query surface), log, settings, random, supabase
│   └── testing/              # in-memory FakeDb (+ resolve_capture_tx mirror) and fixtures
├── start-encounter/          # index.ts = Deno.serve(...); handler.ts = pure, testable logic
├── resolve-capture/
└── admin-register-nfc/
```

Each function folder also has a tiny `deno.json` with the same import map: the Supabase CLI resolves
dependencies **per function** (function `deno.json` → `import_map.json` →
`functions/import_map.json`); the root `deno.json` is what `deno test` / `deno check` use.

## Run locally

```bash
supabase start                                   # DB + Auth + Studio (other module)
cp supabase/functions/.env.local.example supabase/functions/.env.local   # once
supabase functions serve --env-file supabase/functions/.env.local --no-verify-jwt
```

`--no-verify-jwt` disables the gateway's JWT check; the functions verify the token themselves by
calling `auth.getUser(jwt)` with the service-role client (`_shared/auth.ts`), so every request still
needs a valid user JWT. Locally the CLI injects `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY`; in production those come from the platform. No other env var is read.

## Verify

```bash
cd supabase/functions
deno task check     # deno check **/index.ts
deno task test      # deno test — pure logic + in-memory fake, no network, no running Supabase
deno task lint
```

The `test` task prefixes `NODE_OPTIONS= DD_INSTRUMENT_SERVICE_WITH_APM=false` so that hosts with
Datadog single-step instrumentation (which injects `--require dd-trace` into every process through
`/etc/ld.so.preload`) do not break `deno test`. It is a no-op elsewhere.

## End-to-end against the live local stack

`scripts/e2e-local.sh` is a bash + curl + jq + psql test that drives the real stack (it needs
`supabase start` and `supabase functions serve --no-verify-jwt` already running; it never starts,
stops or resets anything). It reads `API_URL`, `ANON_KEY`, `SERVICE_ROLE_KEY` and `DB_URL` from
`supabase status -o env` (env vars override) and walks the whole CONTRACTS flow: signup → profile
trigger, RLS reads (active professors only, `nfc_tags` hidden, anon sees nothing), every
`start-encounter` / `resolve-capture` / `admin-register-nfc` error code, the MISS/EXCELLENT
deterministic outcomes, idempotent replay, wrong-user `FORBIDDEN`, expiry (`expires_at` backdated
via psql → `410`), five parallel resolves on one encounter (exactly one capture row), player-side
write attempts rejected by RLS/grants, full collection completion with a fresh player
(`collection_completed_at`, `collection_progress`, `admin_stats`) and the structured logs (events
present, no JWT/keys/passwords leaked; set `FUNCTIONS_LOG=<file>` to a capture of the serve output,
otherwise it reads `docker logs` of the edge-runtime container). Every row it creates carries a
random suffix (`E2E_SUFFIX` to pin it, `E2E_KEEP=1` to keep them) and is deleted at the end through
psql; seed rows are only read. It prints one `[PASS]`/`[FAIL]`/`[SKIP]` line per check and exits
non-zero on any failure, so it can run in CI against an ephemeral stack:

```bash
FUNCTIONS_LOG=/path/to/functions-serve.log scripts/e2e-local.sh
```

## curl examples

```bash
SUPABASE_URL=http://127.0.0.1:54321
ANON_KEY=$(supabase status -o env | grep ANON_KEY | cut -d= -f2 | tr -d '"')

# 1. Log in as the demo player (seed.sql) and grab the access token
JWT=$(curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"player@profesorgo.local","password":"player12345"}' | jq -r .access_token)

# 2. start-encounter
curl -s -X POST "$SUPABASE_URL/functions/v1/start-encounter" \
  -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
  -d '{"tag_identifier":"DEMO-TAG-01"}'
# → { "encounter_id": "…", "expires_at": "…", "professor": { "id", "display_name", "rarity", "sprite_url", "description" } }

# 3. resolve-capture
curl -s -X POST "$SUPABASE_URL/functions/v1/resolve-capture" \
  -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
  -d '{"encounter_id":"<encounter_id>","throw_quality":"GREAT"}'
# → { "success": true, "professor_id": "…", "collection": { "captured": 1, "total": 8, "completed": false } }
# → { "success": false, "retry_requires_new_nfc_scan": true }

# 4. admin-register-nfc (needs an admin JWT: admin@profesorgo.local / admin12345)
curl -s -X POST "$SUPABASE_URL/functions/v1/admin-register-nfc" \
  -H "Authorization: Bearer $ADMIN_JWT" -H "Content-Type: application/json" \
  -d '{"tag_identifier":"DEMO-TAG-09","professor_id":"00000000-0000-4000-8000-000000000001","active":true}'
# → { "tag": { "id", "tag_identifier", "professor_id", "active", "created_at" } }
```

## Error codes

| Code                   | HTTP | Function(s)                          |
| ---------------------- | ---- | ------------------------------------ |
| `UNAUTHORIZED`         | 401  | all                                  |
| `INVALID_INPUT`        | 400  | all                                  |
| `FORBIDDEN`            | 403  | resolve-capture (other user), admin  |
| `TAG_NOT_FOUND`        | 404  | start-encounter                      |
| `TAG_DISABLED`         | 403  | start-encounter                      |
| `PROFESSOR_DISABLED`   | 403  | start-encounter                      |
| `ALREADY_CAPTURED`     | 409  | start-encounter, resolve-capture     |
| `ENCOUNTER_NOT_FOUND`  | 404  | resolve-capture                      |
| `ENCOUNTER_NOT_ACTIVE` | 409  | resolve-capture                      |
| `ENCOUNTER_EXPIRED`    | 410  | resolve-capture                      |
| `PROFESSOR_NOT_FOUND`  | 404  | admin-register-nfc                   |
| `METHOD_NOT_ALLOWED`   | 405  | all (non-POST)                       |
| `INTERNAL_ERROR`       | 500  | all (DB/RPC failure; details logged) |

Logs are single-line JSON (`_shared/log.ts`) with an `event` name (`encounter_started`,
`capture_resolved`, `invalid_tag`, `duplicate_capture`, `nfc_tag_registered`, …). Secret-looking
keys and JWT-looking values are redacted before writing.

## Input validation

Bodies are parsed by `_shared/http.ts` (`readJsonBody`) and the per-function `parse*Body`, which
delegate every field rule to `_shared/validate.ts`. Everything below answers
`400 { "error": "INVALID_INPUT", "message": "…" }` and never reaches the database.

Transport (`readJsonBody`):

- the body must be valid JSON **and** a JSON object — arrays, `null`, numbers and bare strings are
  rejected;
- the body must be at most `MAX_BODY_BYTES` (8 KiB): an oversized `Content-Length` is refused
  _before_ the body is buffered, and an absent or lying one is caught right after reading.

Fields (`_shared/validate.ts`):

- `tag_identifier` (`parseTagIdentifier`, `start-encounter` + `admin-register-nfc`): must be a
  **string** — numbers, booleans, `null`, arrays and objects are rejected — is **trimmed**, must be
  **non-empty** after trimming, at most **128 characters** (`MAX_TAG_IDENTIFIER_LENGTH`, measured
  after trimming) and must contain **no C0/C1 control characters** (NUL, `\n`, `\r`, `\t`, DEL…).
- `encounter_id` (`parseUuid`, `resolve-capture`): strict canonical UUID,
  `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`, case-insensitive and anchored.
  Braced `{…}`, `urn:uuid:…`, dash-less and whitespace-padded forms are all rejected.
- `throw_quality` (`parseThrowQuality`, `resolve-capture`): exactly `MISS`, `GOOD`, `GREAT` or
  `EXCELLENT`, case-sensitive (`good` is rejected).
- `professor_id` (`parseOptionalUuid`, `admin-register-nfc`): a canonical UUID, or `null`/absent to
  leave the tag unassigned.
- `active` (`parseOptionalBoolean`, `admin-register-nfc`): a boolean when present, defaulting to
  `true` when the key is absent; `null`, `"true"` and `1` are rejected.

Notes:

- **Why 128 characters** for `tag_identifier`: the value is an opaque NDEF payload / tag UID. A
  7-byte NTAG UID is 14 hex characters and the seed tags are `DEMO-TAG-0N`, so 128 leaves a lot of
  room while still bounding what is written to `nfc_tags`, compared against, and echoed into the
  structured logs. Both `start-encounter` and `admin-register-nfc` share the same constant
  (`MAX_TAG_IDENTIFIER_LENGTH`), so a tag that cannot be registered cannot be looked up either.
- Control characters are rejected because Postgres `text` cannot store NUL: without the check that
  input would surface as a `500 INTERNAL_ERROR` instead of a `400`.
- Trimming happens **before** the length check and before the database lookup, so
  `"  DEMO-TAG-01  "` matches the stored `DEMO-TAG-01`.
- **Unknown extra fields are ignored**, not rejected (forward compatibility with older clients);
  every field the functions do read is type-checked.
- Every branch above is covered by `_shared/validate.test.ts` plus the per-function
  `handler.test.ts` (`deno task test`) and, for the HTTP surface, by `scripts/e2e-local.sh`.

## Anti-cheat model, tag secrecy and rate limiting

**Known limitation (accepted for this MVP):** the anti-cheat model rests on the secrecy of
`nfc_tags.tag_identifier`, and there is **no rate limiting or lockout** on `start-encounter`. This
section documents exactly what that buys and what it does not; the rate limiting itself is
deliberately **not** implemented in this repository.

### Enforced server-side today

- **Authentication on every call.** All three functions require `Authorization: Bearer <user JWT>`
  and verify it server-side with `auth.getUser(jwt)` on the service-role client (`_shared/auth.ts`),
  so the token's signature and expiry are checked by GoTrue, not by the client. No anonymous play.
- **The tag identifier is never exposed to players.** `nfc_tags` has RLS with a single policy
  (`nfc_tags: admins full access`, `to authenticated using public.is_admin()`), so a player or an
  anonymous caller reading `/rest/v1/nfc_tags` gets zero rows, and no view or function exposes the
  table. A player only ever learns identifiers by physically scanning tags.
- **Only the server decides an encounter is legitimate.** `start-encounter` checks, in order: the
  tag exists → the tag is `active` → it points at an existing, `active` professor → the player does
  not already own that professor (`ALREADY_CAPTURED`). It then expires the player's previous
  `ACTIVE` encounters for that professor, so a player can hold at most one live encounter per
  professor at a time.
- **Encounters expire.** `expires_at = now() + app_settings.encounter_expiration_seconds` (180 s by
  default); resolving later returns `410 ENCOUNTER_EXPIRED` and marks the row `EXPIRED`.
- **The outcome is computed server-side.**
  `p = clamp(base_capture_rate + throw_bonus[quality], 0, 1)` with `base_capture_rate` read from the
  database, and the roll is generated inside the function with `crypto.getRandomValues`
  (`_shared/random.ts`). The client sends only `throw_quality`; there is no way to pass a roll, a
  probability or a professor id.
- **Resolution is atomic and idempotent.** `public.resolve_capture_tx` runs `select … for update` on
  the encounter, so N parallel `resolve-capture` calls on one encounter produce at most one capture;
  `captures` has `unique (user_id, professor_id)` as the final backstop, and a replay of an
  already-successful encounter returns the same success payload instead of a second capture.
- **Players cannot write game state.** RLS gives players no `insert/update/delete` on `captures` or
  `encounters`; both are written only by the Edge Functions with the service role, and `execute` on
  `resolve_capture_tx` is granted **only** to `service_role` (revoked from `public`, `anon`,
  `authenticated`). Every security-definer function pins `search_path = ''`.
- **Input is validated and logs are redacted** (see "Input validation" above and `_shared/log.ts`).

### What an attacker who learns a tag identifier can do

The identifier is a _static bearer secret_: it is printed/encoded once on the tag, any generic NFC
reader app shows it, and it can be copied into a chat message. Knowing it, an authenticated player
can:

- **Capture that professor without being anywhere near the tag**, from any device, at any time.
  There is no proof of physical presence in the protocol — no geolocation, no device binding, no
  per-scan freshness.
- **Retry until it works.** A failed throw only burns the encounter; `start-encounter` can be called
  again immediately (it just expires the previous `ACTIVE` row) and nothing counts the attempts.
  With `EXCELLENT` the per-attempt probability is `base + 0.20`, so even a `LEGENDARY` professor
  (0.25 + 0.20 = 0.45) falls in ~2 attempts on average and is a near-certainty within 10. Randomness
  is not a defence against repetition.
- **Share it.** One leaked identifier per professor is enough for an entire cohort to complete the
  collection remotely; `collection_completed_at` and the admin stats would then be meaningless.
- **Guess identifiers.** With no rate limit, guessing is bounded only by network throughput, and the
  distinct `TAG_NOT_FOUND` / `TAG_DISABLED` / `PROFESSOR_DISABLED` responses confirm a correct
  guess. Low-entropy identifiers in the seed style (`DEMO-TAG-01`) are enumerable in seconds.

What a leaked identifier still does **not** allow: capturing the same professor twice (unique
constraint), resolving another player's encounter (`403 FORBIDDEN`), listing `nfc_tags` to discover
the other identifiers (RLS), altering probabilities or `base_capture_rate` (admin-only tables), or
writing `captures`/`encounters` directly (RLS + grants).

### Production options

1. **Per-user and per-IP rate limit + lockout on `start-encounter`.** Cheapest and most effective
   first step. Concretely: a sliding/fixed window such as 10 starts per user per minute and 100 per
   hour, plus 30 per IP per minute for shared campus NAT, and a temporary lockout (e.g. 5 minutes)
   after ~10 consecutive `TAG_NOT_FOUND` from the same user or IP — counting _failed_ lookups
   separately is what stops enumeration, since a legitimate player almost never scans an unknown
   tag. Implement it either in front of the function (platform WAF / API gateway rules) or in
   Postgres with an `encounter_attempts(user_id, ip, outcome, created_at)` table plus an index on
   `(user_id, created_at)` and a count check inside the same transaction as the insert; a shared
   store (Redis/Upstash) is the better fit once more than one region serves the function. Pair it
   with a cap on retries per professor per hour so a leaked identifier cannot be brute-forced into a
   capture in one sitting.
2. **Rotating NDEF tokens with HMAC.** Replace the static string with
   `tag_id.counter.HMAC-SHA256(server_key, tag_id ‖ counter)` (truncated), keep `server_key` in the
   function's secrets, and reject any token whose counter is ≤ the last counter accepted for that
   tag, plus a short validity window. A replayed or shared token is then useless, and a leaked one
   burns itself. It requires rewritable tags and a way to advance the counter (a companion writer
   app or a periodic re-provisioning pass), which is why it only makes sense with programmable tags.
3. **NTAG 424 DNA with SUN/SDM.** The tag itself computes a CMAC over a monotonic read counter on
   every tap and exposes both in the NDEF URL; the server verifies the CMAC with the tag's
   diversified AES key and refuses a counter it has already seen. This is the only option in this
   list that provides genuine _proof of tap_: the value changes at every scan, so sharing a
   screenshot or a captured URL is worthless. Cost: pricier tags and an AES
   key-provisioning/derivation process (a master key plus per-tag diversification), with the keys
   stored as function secrets or in a KMS.
4. **Short-lived admin-issued codes** for classes and events. `admin-register-nfc`'s sibling would
   mint a code bound to a professor with a TTL (minutes) and a maximum number of redemptions,
   displayed on the screen next to the professor; `start-encounter` accepts the code as an
   alternative credential. It reuses the existing admin path, needs no new hardware, and bounds the
   damage of a leak to the code's lifetime — a good fallback for tags that are damaged or missing.

Complementary hardening, cheap and independent of the above: give every tag a high-entropy
identifier (e.g. 128 random bits, base32) instead of the readable `DEMO-TAG-NN` pattern, so guessing
is infeasible even without a rate limit; and consider collapsing `TAG_NOT_FOUND` / `TAG_DISABLED`
into one generic response so the API stops confirming which guesses were right (that would change
CONTRACTS §4, so it needs agreement across mobile, admin and this module).
