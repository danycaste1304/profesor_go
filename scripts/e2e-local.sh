#!/usr/bin/env bash
# =============================================================================
# scripts/e2e-local.sh — Profesor GO backend end-to-end test against the LIVE
# local Supabase stack (bash + curl + jq + psql).
# =============================================================================
# Exercises everything docs/CONTRACTS.md promises for the backend: the
# auth.users -> profiles trigger, RLS, the three Edge Functions
# (start-encounter, resolve-capture, admin-register-nfc), the atomic RPC
# resolve_capture_tx (idempotency, expiry, concurrency), collection completion,
# collection_progress / admin_stats and the structured function logs.
#
# Prerequisites (the script never starts, stops or resets anything):
#   * bash 4+, curl, jq, psql
#   * `supabase start` done (migrations + seed.sql applied)
#   * `supabase functions serve --no-verify-jwt` running
#
# Configuration — env vars override; anything missing is read from
# `supabase status -o env`:
#   API_URL, ANON_KEY, SERVICE_ROLE_KEY, DB_URL
#   FUNCTIONS_LOG   file that captures the `functions serve` output. Default:
#                   `docker logs` of the supabase_edge_runtime_* container.
#                   Step 14 is skipped when neither is available.
#   E2E_SUFFIX      suffix for the rows created by this run (default: random)
#   E2E_KEEP=1      keep the created rows for debugging (default: delete them)
#
# Every row the script creates carries the suffix (users e2e-<suffix>-*@…,
# tags E2E-<SUFFIX>-*, professors "E2E <suffix> …") and is deleted at the end
# through psql (also on abnormal exit). Seed rows are only read, never changed,
# so the script is safe to run while other people share the same stack.
#
# Output: one [PASS]/[FAIL]/[SKIP] line per check plus a summary.
# Exit code: 0 when every check passed, 1 otherwise, 2 on a fatal setup error.
# =============================================================================
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/tools/bin:$PATH"

# Homebrew keeps libpq keg-only on macOS; locate its psql without requiring
# each caller to change their shell profile.
if ! command -v psql >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
  LIBPQ_PREFIX="$(brew --prefix libpq 2>/dev/null)" || LIBPQ_PREFIX=""
  if [[ -n "$LIBPQ_PREFIX" && -x "$LIBPQ_PREFIX/bin/psql" ]]; then
    export PATH="$LIBPQ_PREFIX/bin:$PATH"
  fi
fi

# ----------------------------------------------------------------------------
# Constants / fixtures
# ----------------------------------------------------------------------------
SEED_PROF_PREFIX="00000000-0000-4000-8000-00000000000"
SEED_PROF1="${SEED_PROF_PREFIX}1"
SEED_PROF2="${SEED_PROF_PREFIX}2"
SEED_PROF3="${SEED_PROF_PREFIX}3"
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@profesorgo.local}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin12345}
MAX_CAPTURE_ATTEMPTS=${MAX_CAPTURE_ATTEMPTS:-40}
PARALLEL_RESOLVES=5

SUFFIX=${E2E_SUFFIX:-$(date +%s)$RANDOM}
SUFFIX=${SUFFIX//[^A-Za-z0-9]/}
SUF_LC=$(tr '[:upper:]' '[:lower:]' <<<"$SUFFIX")
SUF_UC=$(tr '[:lower:]' '[:upper:]' <<<"$SUFFIX")
TAG_PREFIX="E2E-${SUF_UC}-"
EMAIL_PREFIX="e2e-${SUF_LC}-"
EMAIL_DOMAIN="profesorgo.local"
PROF_NAME_PREFIX="E2E ${SUFFIX} "
PASSWORD="e2e-pass-${SUF_LC}"

# ----------------------------------------------------------------------------
# Reporting
# ----------------------------------------------------------------------------
PASS_COUNT=0; FAIL_COUNT=0; SKIP_COUNT=0
FAILED=()
STEP="setup"

step() { STEP="$1"; printf '\n== %s ==\n' "$1"; }
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
skip() { SKIP_COUNT=$((SKIP_COUNT + 1)); printf '  [SKIP] %s\n' "$1"; }
fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED+=("$STEP :: $1")
  printf '  [FAIL] %s\n' "$1"; shift
  local line; for line in "$@"; do printf '         %s\n' "$line"; done
}
short() { local s=${1//$'\n'/ }; printf '%s' "${s:0:220}"; }

# assert_eq LABEL EXPECTED ACTUAL
assert_eq() {
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1" "expected: $2" "actual:   $3"; fi
}
# assert_true LABEL VALUE  (VALUE must be the literal string "true")
assert_true() { assert_eq "$1" "true" "$2"; }
# assert_status LABEL HTTP_CODE [ERROR_CODE]  — checks the last HTTP call
assert_status() {
  local label=$1 want=$2 code=${3:-} got_err
  got_err=$(jq -r '.error // empty' <<<"$HTTP_BODY" 2>/dev/null)
  if [[ "$HTTP_CODE" == "$want" && ( -z "$code" || "$got_err" == "$code" ) ]]; then
    pass "$label -> HTTP $HTTP_CODE${got_err:+ $got_err}"
  else
    fail "$label" "expected: HTTP $want${code:+ $code}" "actual:   HTTP $HTTP_CODE $(short "$HTTP_BODY")"
  fi
}
# assert_status_in LABEL "401 403"  — any of the listed HTTP codes
assert_status_in() {
  local label=$1 want=$2 c
  for c in $want; do
    if [[ "$HTTP_CODE" == "$c" ]]; then pass "$label -> HTTP $HTTP_CODE"; return; fi
  done
  fail "$label" "expected: HTTP in [$want]" "actual:   HTTP $HTTP_CODE $(short "$HTTP_BODY")"
}

die() { printf '\nFATAL (%s): %s\n' "$STEP" "$*" >&2; exit 2; }

# ----------------------------------------------------------------------------
# Transport helpers
# ----------------------------------------------------------------------------
TMP=$(mktemp -d "${TMPDIR:-/tmp}/e2e-local.XXXXXX")
HTTP_CODE=""; HTTP_BODY=""

# http METHOD URL [curl args...]  -> HTTP_CODE / HTTP_BODY
http() {
  local method=$1 url=$2; shift 2
  local out="$TMP/body.$RANDOM$RANDOM"
  HTTP_CODE=$(curl -sS --max-time 60 -o "$out" -w '%{http_code}' -X "$method" "$url" "$@" 2>>"$TMP/curl.err") || HTTP_CODE="000"
  HTTP_BODY=$(cat "$out" 2>/dev/null || true)
  rm -f "$out"
}
# jv JQ_EXPR  -> raw value from the last body
jv() { jq -rc "$1" <<<"$HTTP_BODY" 2>/dev/null; }   # -c: arrays/objects stay single-line

# fn NAME JWT BODY  — POST to an Edge Function (JWT "" = no Authorization header)
fn() {
  local name=$1 jwt=$2 body=$3
  local -a args=(-H "Content-Type: application/json" --data-raw "$body")
  [[ -n "$jwt" ]] && args+=(-H "Authorization: Bearer $jwt")
  http POST "$FUNCTIONS_URL/$name" "${args[@]}"
}
# rest JWT METHOD PATH [BODY]  — PostgREST call. JWT "" = anonymous;
# JWT = SERVICE_ROLE_KEY = service role (bypasses RLS).
rest() {
  local jwt=$1 method=$2 path=$3 body=${4:-}
  local apikey=$ANON_KEY
  [[ "$jwt" == "$SERVICE_ROLE_KEY" ]] && apikey=$SERVICE_ROLE_KEY
  local -a args=(-H "apikey: $apikey" -H "Content-Type: application/json")
  [[ -n "$jwt" ]] && args+=(-H "Authorization: Bearer $jwt")
  [[ "$method" != "GET" ]] && args+=(-H "Prefer: return=representation")
  [[ -n "$body" ]] && args+=(--data-raw "$body")
  http "$method" "$API_URL/rest/v1/$path" "${args[@]}"
}
sr() { rest "$SERVICE_ROLE_KEY" "$@"; }

# sql QUERY  -> tuples only, unaligned, stops on error
sql() { psql "$DB_URL" -X -q -A -t -v ON_ERROR_STOP=1 -c "$1"; }

login() { # login EMAIL PASSWORD -> prints access_token
  http POST "$API_URL/auth/v1/token?grant_type=password" -H "apikey: $ANON_KEY" \
    -H "Content-Type: application/json" \
    --data-raw "$(jq -cn --arg e "$1" --arg p "$2" '{email:$e,password:$p}')"
  jv '.access_token // empty'
}
signup() { # signup EMAIL PASSWORD DISPLAY_NAME -> HTTP_BODY (access_token, user.id)
  http POST "$API_URL/auth/v1/signup" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
    --data-raw "$(jq -cn --arg e "$1" --arg p "$2" --arg d "$3" '{email:$e,password:$p,data:{display_name:$d}}')"
}
json() { jq -cn "$@"; }   # json --arg k v '{...}'
is_uuid() { [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; }
iso_to_epoch() { jq -rn --arg t "$1" '$t | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601' 2>/dev/null; }

# encounter_status ENCOUNTER_ID -> status via service role
encounter_status() { sr GET "encounters?id=eq.$1&select=status"; jv '.[0].status // "missing"'; }
# capture_count USER_ID PROFESSOR_ID
capture_count() { sr GET "captures?user_id=eq.$1&professor_id=eq.$2&select=id"; jv 'length'; }

# ----------------------------------------------------------------------------
# Cleanup (also wired to EXIT)
# ----------------------------------------------------------------------------
CLEANED=0
cleanup_rows() {
  [[ -n "${DB_URL:-}" ]] || return 0
  sql "delete from auth.users where email like '${EMAIL_PREFIX}%@${EMAIL_DOMAIN}';
       delete from public.nfc_tags where tag_identifier like '${TAG_PREFIX}%';
       delete from public.professors where name like '${PROF_NAME_PREFIX}%';" >/dev/null
  CLEANED=1
}
on_exit() {
  local rc=$?
  if (( CLEANED == 0 )) && [[ -n "${DB_URL:-}" ]]; then
    if [[ "${E2E_KEEP:-0}" == "1" ]]; then
      echo "E2E_KEEP=1: leaving the rows with suffix '$SUFFIX' in place"
    else
      cleanup_rows 2>/dev/null || echo "WARNING: cleanup of suffix '$SUFFIX' failed" >&2
    fi
  fi
  rm -rf "$TMP"
  exit "$rc"
}
trap on_exit EXIT

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
load_config() {
  local k v env=""
  if [[ -z "${API_URL:-}" || -z "${ANON_KEY:-}" || -z "${SERVICE_ROLE_KEY:-}" || -z "${DB_URL:-}" ]]; then
    command -v supabase >/dev/null 2>&1 \
      || die "set API_URL, ANON_KEY, SERVICE_ROLE_KEY and DB_URL (supabase CLI not found to read them)"
    env=$(cd "$ROOT" && supabase status -o env 2>/dev/null) \
      || die "'supabase status' failed — is the local stack running? (supabase start)"
    for k in API_URL ANON_KEY SERVICE_ROLE_KEY DB_URL; do
      if [[ -z "${!k:-}" ]]; then
        v=$(grep -E "^$k=" <<<"$env" | head -1 | cut -d= -f2- | tr -d '"')
        [[ -n "$v" ]] || die "could not read $k from 'supabase status -o env'"
        printf -v "$k" '%s' "$v"
      fi
    done
  fi
  API_URL=${API_URL%/}
  FUNCTIONS_URL="$API_URL/functions/v1"
  export PGCONNECT_TIMEOUT=5
}

LOG_SOURCE=""; EDGE_CONTAINER=""
detect_log_source() {
  if [[ -n "${FUNCTIONS_LOG:-}" ]]; then
    [[ -r "$FUNCTIONS_LOG" ]] || die "FUNCTIONS_LOG=$FUNCTIONS_LOG is not readable"
    LOG_SOURCE="file"
  elif command -v docker >/dev/null 2>&1; then
    EDGE_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -m1 '^supabase_edge_runtime_' || true)
    [[ -n "$EDGE_CONTAINER" ]] && LOG_SOURCE="docker"
  fi
}
read_log() {
  case "$LOG_SOURCE" in
    file) cat "$FUNCTIONS_LOG" ;;
    docker) docker logs "$EDGE_CONTAINER" 2>&1 ;;
    *) return 1 ;;
  esac
}

preflight() {
  local t
  for t in curl jq psql; do command -v "$t" >/dev/null 2>&1 || die "missing tool: $t"; done
  sql "select 1" >/dev/null 2>&1 || die "cannot connect to DB_URL with psql"
  http GET "$API_URL/rest/v1/" -H "apikey: $ANON_KEY"
  [[ "$HTTP_CODE" == "200" ]] || die "REST API not reachable at $API_URL (HTTP $HTTP_CODE)"
  fn start-encounter "" '{}'
  [[ "$HTTP_CODE" == "401" ]] \
    || die "Edge Functions are not being served at $FUNCTIONS_URL (HTTP $HTTP_CODE) — run 'supabase functions serve --no-verify-jwt'"
  detect_log_source
  printf 'API_URL=%s\nDB=%s\nsuffix=%s\nlog source=%s\n' "$API_URL" "${DB_URL#*@}" "$SUFFIX" \
    "${LOG_SOURCE:-none}${FUNCTIONS_LOG:+ ($FUNCTIONS_LOG)}${EDGE_CONTAINER:+ ($EDGE_CONTAINER)}"
}

# ----------------------------------------------------------------------------
# Fixtures owned by this run (created with psql, service-role semantics)
# ----------------------------------------------------------------------------
INACTIVE_PROF_ID=""; TAG_INACTIVE_PROF="${TAG_PREFIX}INACTIVE-PROF"; TAG_DISABLED="${TAG_PREFIX}DISABLED"
TAG_UNKNOWN="${TAG_PREFIX}UNKNOWN"; TAG_ADMIN="${TAG_PREFIX}ADMIN"
create_fixtures() {
  INACTIVE_PROF_ID=$(sql "with p as (
      insert into public.professors (name, display_name, description, rarity, base_capture_rate, active)
      values ('${PROF_NAME_PREFIX}Inactive', 'Prof. E2E Inactive', 'e2e fixture', 'COMMON', 0.80, false)
      returning id)
    insert into public.nfc_tags (professor_id, tag_identifier, active)
    select id, '${TAG_INACTIVE_PROF}', true from p returning professor_id;") \
    || die "could not create the inactive professor fixture"
  sql "insert into public.nfc_tags (professor_id, tag_identifier, active)
       values ('${SEED_PROF1}', '${TAG_DISABLED}', false);" >/dev/null \
    || die "could not create the disabled tag fixture"
  is_uuid "$INACTIVE_PROF_ID" || die "unexpected fixture id: $INACTIVE_PROF_ID"
}

# ============================================================================
# Test steps
# ============================================================================
P1_JWT=""; P1_ID=""; P1_EMAIL="${EMAIL_PREFIX}p1@${EMAIL_DOMAIN}"
P2_JWT=""; P2_ID=""; P2_EMAIL="${EMAIL_PREFIX}p2@${EMAIL_DOMAIN}"
P3_JWT=""; P3_ID=""; P3_EMAIL="${EMAIL_PREFIX}p3@${EMAIL_DOMAIN}"
ADMIN_JWT=""
ENC1=""; ENC2=""; ENC3=""; ENC_FAILED_ID=""; ENC_SUCCESS_ID=""
EXPECTED_EXPIRATION=180

step_1_signup() {
  step "1. signup -> profiles trigger"
  signup "$P1_EMAIL" "$PASSWORD" "E2E Player One $SUFFIX"
  assert_status "POST /auth/v1/signup (player 1)" 200
  P1_JWT=$(jv '.access_token // empty'); P1_ID=$(jv '.user.id // empty')
  [[ -n "$P1_JWT" ]] && pass "signup returned a session (access_token)" || fail "signup returned no access_token" "$(short "$HTTP_BODY")"
  is_uuid "$P1_ID" && pass "signup returned user.id ($P1_ID)" || die "signup returned no user id — cannot continue"
  sr GET "profiles?id=eq.${P1_ID}&select=id,email,display_name,role,collection_completed_at"
  assert_eq "profile row exists (service_role)" "1" "$(jv 'length')"
  assert_eq "profile.display_name from signup metadata" "E2E Player One $SUFFIX" "$(jv '.[0].display_name')"
  assert_eq "profile.role defaults to player" "player" "$(jv '.[0].role')"
  assert_eq "profile.email mirrored" "$P1_EMAIL" "$(jv '.[0].email')"
  assert_eq "profile.collection_completed_at is null" "null" "$(jv '.[0].collection_completed_at')"
}

step_2_reads() {
  step "2. RLS reads: professors (active only), nfc_tags hidden, anon sees nothing"
  create_fixtures
  local try player_ids="" sr_ids="?" player_body="" all_active=""
  for try in 1 2 3; do
    rest "$P1_JWT" GET "professors?select=id,active&order=id"; player_body=$HTTP_BODY
    player_ids=$(jq -c '[.[].id] | sort' <<<"$player_body" 2>/dev/null)
    sr GET "professors?select=id&active=eq.true&order=id"
    sr_ids=$(jv '[.[].id] | sort')
    [[ "$player_ids" == "$sr_ids" ]] && break
  done
  assert_eq "player sees exactly the active professors (ids match service_role active set)" "$sr_ids" "$player_ids"
  all_active=$(jq -r 'all(.active == true)' <<<"$player_body" 2>/dev/null)
  assert_true "every professor row visible to the player has active=true" "$all_active"
  assert_true "player list contains the 8 seed professors" \
    "$(jq -r --arg p "$SEED_PROF_PREFIX" '[.[].id] as $ids | [range(1;9) | $p + tostring] | all(. as $x | $ids | index($x) != null)' <<<"$player_body" 2>/dev/null)"
  assert_eq "player does not see the inactive professor fixture" "false" \
    "$(jq -r --arg id "$INACTIVE_PROF_ID" '[.[].id] | index($id) != null' <<<"$player_body" 2>/dev/null)"
  sr GET "professors?id=eq.${INACTIVE_PROF_ID}&select=id"
  assert_eq "service_role does see the inactive professor fixture" "1" "$(jv 'length')"

  rest "$P1_JWT" GET "nfc_tags?select=id,tag_identifier"
  if [[ "$HTTP_CODE" == "200" && "$(jv 'length')" == "0" ]] || [[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
    pass "player cannot read nfc_tags (HTTP $HTTP_CODE, $(short "$HTTP_BODY"))"
  else
    fail "player can read nfc_tags" "HTTP $HTTP_CODE $(short "$HTTP_BODY")"
  fi
  local t
  for t in professors nfc_tags captures encounters profiles app_settings; do
    rest "" GET "$t?select=*"
    if [[ "$HTTP_CODE" == "200" && "$(jv 'length')" == "0" ]] || [[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
      pass "anon gets nothing from $t (HTTP $HTTP_CODE)"
    else
      fail "anon can read $t" "HTTP $HTTP_CODE $(short "$HTTP_BODY")"
    fi
  done
}

step_3_start_encounter_errors() {
  step "3. start-encounter error paths"
  fn start-encounter "" '{"tag_identifier":"DEMO-TAG-01"}'
  assert_status "no JWT" 401 UNAUTHORIZED
  fn start-encounter "not-a-jwt" '{"tag_identifier":"DEMO-TAG-01"}'
  assert_status "garbage JWT" 401 UNAUTHORIZED
  fn start-encounter "$P1_JWT" "$(json --arg t "$TAG_UNKNOWN" '{tag_identifier:$t}')"
  assert_status "unknown tag" 404 TAG_NOT_FOUND
  fn start-encounter "$P1_JWT" "$(json --arg t "$TAG_DISABLED" '{tag_identifier:$t}')"
  assert_status "disabled tag" 403 TAG_DISABLED
  fn start-encounter "$P1_JWT" "$(json --arg t "$TAG_INACTIVE_PROF" '{tag_identifier:$t}')"
  assert_status "tag of an inactive professor" 403 PROFESSOR_DISABLED
  fn start-encounter "$P1_JWT" '{}'
  assert_status "invalid body {}" 400 INVALID_INPUT
  fn start-encounter "$P1_JWT" '{"tag_identifier":""}'
  assert_status "invalid body (empty tag_identifier)" 400 INVALID_INPUT
  fn start-encounter "$P1_JWT" '{"tag_identifier":42}'
  assert_status "invalid body (numeric tag_identifier)" 400 INVALID_INPUT
  fn start-encounter "$P1_JWT" 'not json'
  assert_status "invalid body (not JSON)" 400 INVALID_INPUT
  fn start-encounter "$P1_JWT" '[]'
  assert_status "invalid body (array)" 400 INVALID_INPUT
  http GET "$FUNCTIONS_URL/start-encounter" -H "Authorization: Bearer $P1_JWT"
  assert_status "GET is rejected" 405 METHOD_NOT_ALLOWED
}

step_4_start_encounter_ok() {
  step "4. start-encounter DEMO-TAG-01 (happy path + re-scan expires the previous encounter)"
  sr GET "app_settings?key=eq.encounter_expiration_seconds&select=value"
  local cfg; cfg=$(jv '.[0].value // empty')
  [[ "$cfg" =~ ^[0-9]+$ ]] && EXPECTED_EXPIRATION=$cfg
  local t0 t1 exp exp_s delta
  t0=$(date -u +%s)
  fn start-encounter "$P1_JWT" '{"tag_identifier":"DEMO-TAG-01"}'
  t1=$(date -u +%s)
  assert_status "start-encounter DEMO-TAG-01" 200
  ENC1=$(jv '.encounter_id // empty')
  is_uuid "$ENC1" && pass "encounter_id is a uuid ($ENC1)" || die "no encounter_id in response: $(short "$HTTP_BODY")"
  exp=$(jv '.expires_at // empty'); exp_s=$(iso_to_epoch "$exp")
  if [[ -n "$exp_s" ]]; then
    delta=$((exp_s - t0))
    if (( delta >= EXPECTED_EXPIRATION - 5 && delta <= EXPECTED_EXPIRATION + 5 + (t1 - t0) )); then
      pass "expires_at ≈ now + ${EXPECTED_EXPIRATION}s (delta ${delta}s)"
    else
      fail "expires_at not ≈ now + ${EXPECTED_EXPIRATION}s" "expires_at=$exp delta=${delta}s"
    fi
  else
    fail "expires_at is not ISO-8601" "expires_at=$exp"
  fi
  assert_eq "professor.id is seed professor 1" "$SEED_PROF1" "$(jv '.professor.id')"
  assert_eq "professor.display_name" "Prof. Ada" "$(jv '.professor.display_name')"
  assert_eq "professor.rarity" "COMMON" "$(jv '.professor.rarity')"
  assert_true "professor has sprite_url and description keys" "$(jv '.professor | has("sprite_url") and has("description")')"
  assert_eq "professor.description comes from the seed" "string" "$(jv '.professor.description | type')"
  assert_eq "response has exactly the contract keys" '["encounter_id","expires_at","professor"]' "$(jv 'keys')"
  sr GET "encounters?id=eq.${ENC1}&select=status,user_id,professor_id"
  assert_eq "encounter row is ACTIVE" "ACTIVE" "$(jv '.[0].status')"
  assert_eq "encounter row belongs to player 1" "$P1_ID" "$(jv '.[0].user_id')"
  assert_eq "encounter row references professor 1" "$SEED_PROF1" "$(jv '.[0].professor_id')"
  rest "$P1_JWT" GET "encounters?id=eq.${ENC1}&select=id"
  assert_eq "player can read own encounter via REST" "1" "$(jv 'length')"

  fn start-encounter "$P1_JWT" '{"tag_identifier":"DEMO-TAG-01"}'
  assert_status "start-encounter DEMO-TAG-01 again" 200
  ENC2=$(jv '.encounter_id // empty')
  is_uuid "$ENC2" || die "no encounter_id in second response"
  [[ "$ENC2" != "$ENC1" ]] && pass "second call returns a new encounter ($ENC2)" || fail "second call returned the same encounter id"
  assert_eq "previous encounter became EXPIRED" "EXPIRED" "$(encounter_status "$ENC1")"
  assert_eq "new encounter is ACTIVE" "ACTIVE" "$(encounter_status "$ENC2")"
}

step_5_resolve_miss() {
  step "5. resolve-capture MISS -> failure, FAILED, then ENCOUNTER_NOT_ACTIVE"
  fn resolve-capture "$P1_JWT" "$(json --arg e "$ENC2" '{encounter_id:$e,throw_quality:"MISS"}')"
  assert_status "resolve MISS" 200
  assert_eq "success:false" "false" "$(jv '.success')"
  assert_true "retry_requires_new_nfc_scan:true" "$(jv '.retry_requires_new_nfc_scan')"
  assert_eq "failure body has exactly the contract keys" '["retry_requires_new_nfc_scan","success"]' "$(jv 'keys')"
  assert_eq "encounter is FAILED" "FAILED" "$(encounter_status "$ENC2")"
  assert_eq "no capture row was created" "0" "$(capture_count "$P1_ID" "$SEED_PROF1")"
  ENC_FAILED_ID=$ENC2
  fn resolve-capture "$P1_JWT" "$(json --arg e "$ENC2" '{encounter_id:$e,throw_quality:"EXCELLENT"}')"
  assert_status "resolving the FAILED encounter again" 409 ENCOUNTER_NOT_ACTIVE
}

step_6_resolve_excellent() {
  step "6. resolve-capture EXCELLENT (p=1.0) -> success, idempotent replay, ALREADY_CAPTURED"
  sr GET "professors?select=id&active=eq.true"; local active_total; active_total=$(jv 'length')
  fn start-encounter "$P1_JWT" '{"tag_identifier":"DEMO-TAG-01"}'
  assert_status "start-encounter DEMO-TAG-01 (third)" 200
  ENC3=$(jv '.encounter_id // empty'); is_uuid "$ENC3" || die "no encounter_id"
  fn resolve-capture "$P1_JWT" "$(json --arg e "$ENC3" '{encounter_id:$e,throw_quality:"EXCELLENT"}')"
  assert_status "resolve EXCELLENT" 200
  assert_true "success:true" "$(jv '.success')"
  assert_eq "professor_id" "$SEED_PROF1" "$(jv '.professor_id')"
  assert_eq "collection.captured" "1" "$(jv '.collection.captured')"
  assert_eq "collection.total = active professors (seed: 8, live: $active_total)" "$active_total" "$(jv '.collection.total')"
  [[ "$active_total" == "8" ]] || echo "         note: live active professor count is $active_total, not the seed's 8 (foreign rows present)"
  assert_eq "collection.completed" "false" "$(jv '.collection.completed')"
  assert_eq "success body has exactly the contract keys" '["collection","professor_id","success"]' "$(jv 'keys')"
  assert_eq "encounter is SUCCESS" "SUCCESS" "$(encounter_status "$ENC3")"
  ENC_SUCCESS_ID=$ENC3
  sr GET "captures?user_id=eq.${P1_ID}&professor_id=eq.${SEED_PROF1}&select=id,encounter_id,throw_quality"
  assert_eq "exactly one capture row" "1" "$(jv 'length')"
  assert_eq "capture.encounter_id" "$ENC3" "$(jv '.[0].encounter_id')"
  assert_eq "capture.throw_quality" "EXCELLENT" "$(jv '.[0].throw_quality')"
  rest "$P1_JWT" GET "captures?select=id,professor_id"
  assert_eq "player reads own capture via REST" "1" "$(jv 'length')"

  fn resolve-capture "$P1_JWT" "$(json --arg e "$ENC3" '{encounter_id:$e,throw_quality:"EXCELLENT"}')"
  assert_status "replay of the same resolve" 200
  assert_true "replay -> success:true (idempotent)" "$(jv '.success')"
  assert_eq "replay -> professor_id" "$SEED_PROF1" "$(jv '.professor_id')"
  assert_eq "replay -> collection.captured still 1" "1" "$(jv '.collection.captured')"
  assert_eq "still exactly one capture row after replay" "1" "$(capture_count "$P1_ID" "$SEED_PROF1")"
  fn resolve-capture "$P1_JWT" "$(json --arg e "$ENC3" '{encounter_id:$e,throw_quality:"MISS"}')"
  assert_status "replay with MISS after SUCCESS" 200
  assert_true "replay with MISS still reports success:true" "$(jv '.success')"
  fn start-encounter "$P1_JWT" '{"tag_identifier":"DEMO-TAG-01"}'
  assert_status "start-encounter DEMO-TAG-01 after capture" 409 ALREADY_CAPTURED
}

step_7_wrong_user() {
  step "7. another player cannot resolve someone else's encounter"
  signup "$P2_EMAIL" "$PASSWORD" "E2E Player Two $SUFFIX"
  assert_status "signup player 2" 200
  P2_JWT=$(jv '.access_token // empty'); P2_ID=$(jv '.user.id // empty')
  is_uuid "$P2_ID" || die "signup of player 2 failed"
  fn start-encounter "$P1_JWT" '{"tag_identifier":"DEMO-TAG-02"}'
  assert_status "player 1 starts DEMO-TAG-02" 200
  local enc; enc=$(jv '.encounter_id')
  fn resolve-capture "$P2_JWT" "$(json --arg e "$enc" '{encounter_id:$e,throw_quality:"EXCELLENT"}')"
  assert_status "player 2 resolves player 1's encounter" 403 FORBIDDEN
  assert_eq "encounter is still ACTIVE" "ACTIVE" "$(encounter_status "$enc")"
  assert_eq "no capture for player 2" "0" "$(capture_count "$P2_ID" "$SEED_PROF2")"
  rest "$P2_JWT" GET "encounters?id=eq.${enc}&select=id"
  assert_eq "player 2 cannot even read player 1's encounter" "0" "$(jv 'length')"
}

step_8_expiry() {
  step "8. expired encounter -> 410 ENCOUNTER_EXPIRED"
  fn start-encounter "$P1_JWT" '{"tag_identifier":"DEMO-TAG-03"}'
  assert_status "player 1 starts DEMO-TAG-03" 200
  local enc; enc=$(jv '.encounter_id')
  sql "update public.encounters set expires_at = now() - interval '1 minute' where id = '${enc}' and user_id = '${P1_ID}';" >/dev/null \
    || fail "could not backdate expires_at via psql"
  fn resolve-capture "$P1_JWT" "$(json --arg e "$enc" '{encounter_id:$e,throw_quality:"EXCELLENT"}')"
  assert_status "resolve after expiry" 410 ENCOUNTER_EXPIRED
  assert_eq "encounter marked EXPIRED" "EXPIRED" "$(encounter_status "$enc")"
  assert_eq "no capture row" "0" "$(capture_count "$P1_ID" "$SEED_PROF3")"
  fn resolve-capture "$P1_JWT" "$(json --arg e "$enc" '{encounter_id:$e,throw_quality:"EXCELLENT"}')"
  assert_status "resolve again after EXPIRED" 409 ENCOUNTER_NOT_ACTIVE
}

step_9_resolve_input_errors() {
  step "9. resolve-capture input validation"
  local unknown; unknown=$(uuidgen 2>/dev/null || sql "select gen_random_uuid()")
  fn resolve-capture "$P1_JWT" "$(json --arg e "$unknown" '{encounter_id:$e,throw_quality:"SUPER"}')"
  assert_status "invalid throw_quality" 400 INVALID_INPUT
  fn resolve-capture "$P1_JWT" '{"encounter_id":"not-a-uuid","throw_quality":"MISS"}'
  assert_status "non-uuid encounter_id" 400 INVALID_INPUT
  fn resolve-capture "$P1_JWT" '{"throw_quality":"MISS"}'
  assert_status "missing encounter_id" 400 INVALID_INPUT
  fn resolve-capture "$P1_JWT" "$(json --arg e "$unknown" '{encounter_id:$e}')"
  assert_status "missing throw_quality" 400 INVALID_INPUT
  fn resolve-capture "$P1_JWT" 'null'
  assert_status "null body" 400 INVALID_INPUT
  fn resolve-capture "$P1_JWT" "$(json --arg e "$unknown" '{encounter_id:$e,throw_quality:"GOOD"}')"
  assert_status "unknown encounter uuid" 404 ENCOUNTER_NOT_FOUND
  fn resolve-capture "" "$(json --arg e "$unknown" '{encounter_id:$e,throw_quality:"GOOD"}')"
  assert_status "no JWT" 401 UNAUTHORIZED
}

step_10_concurrency() {
  step "10. concurrency: ${PARALLEL_RESOLVES} parallel EXCELLENT resolves on one encounter"
  fn start-encounter "$P1_JWT" '{"tag_identifier":"DEMO-TAG-02"}'
  assert_status "player 1 starts DEMO-TAG-02 (fresh)" 200
  local enc body i code ok=0 succ=0
  enc=$(jv '.encounter_id'); body=$(json --arg e "$enc" '{encounter_id:$e,throw_quality:"EXCELLENT"}')
  for i in $(seq 1 "$PARALLEL_RESOLVES"); do
    curl -sS --max-time 60 -o "$TMP/par.$i.body" -w '%{http_code}' -X POST "$FUNCTIONS_URL/resolve-capture" \
      -H "Authorization: Bearer $P1_JWT" -H "Content-Type: application/json" --data-raw "$body" \
      >"$TMP/par.$i.code" 2>/dev/null &
  done
  wait
  for i in $(seq 1 "$PARALLEL_RESOLVES"); do
    code=$(cat "$TMP/par.$i.code" 2>/dev/null || echo 000)
    [[ "$code" == "200" ]] && ok=$((ok + 1))
    [[ "$(jq -r '.success' "$TMP/par.$i.body" 2>/dev/null)" == "true" ]] && succ=$((succ + 1))
  done
  if (( ok != PARALLEL_RESOLVES || succ != PARALLEL_RESOLVES )); then
    for i in $(seq 1 "$PARALLEL_RESOLVES"); do echo "         #$i HTTP $(cat "$TMP/par.$i.code" 2>/dev/null) $(short "$(cat "$TMP/par.$i.body" 2>/dev/null)")"; done
  fi
  assert_eq "all parallel requests returned HTTP 200" "$PARALLEL_RESOLVES" "$ok"
  assert_eq "all parallel requests returned success:true" "$PARALLEL_RESOLVES" "$succ"
  assert_eq "exactly ONE capture row for (player 1, professor 2)" "1" "$(capture_count "$P1_ID" "$SEED_PROF2")"
  assert_eq "encounter is SUCCESS" "SUCCESS" "$(encounter_status "$enc")"
  sr GET "captures?user_id=eq.${P1_ID}&select=id"
  assert_eq "player 1 has 2 captures in total" "2" "$(jv 'length')"
}

step_11_player_writes() {
  step "11. player-side writes are rejected by RLS / grants"
  rest "$P2_JWT" POST "captures" "$(json --arg u "$P2_ID" --arg p "$SEED_PROF1" '{user_id:$u,professor_id:$p,throw_quality:"GOOD"}')"
  assert_status_in "POST /rest/v1/captures as player" "401 403"
  assert_eq "no capture row was inserted" "0" "$(capture_count "$P2_ID" "$SEED_PROF1")"
  rest "$P2_JWT" POST "encounters" "$(json --arg u "$P2_ID" --arg p "$SEED_PROF1" '{user_id:$u,professor_id:$p,expires_at:"2099-01-01T00:00:00Z"}')"
  assert_status_in "POST /rest/v1/encounters as player" "401 403"
  rest "$P2_JWT" POST "rpc/resolve_capture_tx" "$(json --arg e "$ENC_SUCCESS_ID" --arg u "$P1_ID" '{p_encounter_id:$e,p_user_id:$u,p_throw_quality:"EXCELLENT"}')"
  assert_status_in "POST /rest/v1/rpc/resolve_capture_tx as player" "401 403"
  rest "" POST "rpc/resolve_capture_tx" "$(json --arg e "$ENC_SUCCESS_ID" --arg u "$P1_ID" '{p_encounter_id:$e,p_user_id:$u,p_throw_quality:"EXCELLENT"}')"
  assert_status_in "POST /rest/v1/rpc/resolve_capture_tx as anon" "401 403"
  rest "$P2_JWT" PATCH "profiles?id=eq.${P2_ID}" '{"role":"admin"}'
  assert_status_in "PATCH own profiles.role = admin" "400 401 403"
  sr GET "profiles?id=eq.${P2_ID}&select=role,display_name"
  assert_eq "profiles.role unchanged (player)" "player" "$(jv '.[0].role')"
  rest "$P2_JWT" PATCH "profiles?id=eq.${P2_ID}" '{"collection_completed_at":"2020-01-01T00:00:00Z"}'
  assert_status_in "PATCH own profiles.collection_completed_at" "400 401 403"
  sr GET "profiles?id=eq.${P2_ID}&select=collection_completed_at"
  assert_eq "profiles.collection_completed_at unchanged (null)" "null" "$(jv '.[0].collection_completed_at')"
  rest "$P2_JWT" PATCH "profiles?id=eq.${P2_ID}" '{"display_name":"E2E Renamed"}'
  assert_status "PATCH own profiles.display_name (allowed)" 200
  sr GET "profiles?id=eq.${P2_ID}&select=display_name"
  assert_eq "profiles.display_name updated" "E2E Renamed" "$(jv '.[0].display_name')"
  rest "$P2_JWT" PATCH "profiles?id=eq.${P1_ID}" '{"display_name":"hacked"}'
  sr GET "profiles?id=eq.${P1_ID}&select=display_name"
  assert_eq "cannot rename another player's profile" "E2E Player One $SUFFIX" "$(jv '.[0].display_name')"
  rest "$P1_JWT" DELETE "captures?user_id=eq.${P1_ID}"
  assert_eq "DELETE own captures as player has no effect" "2" "$(sr GET "captures?user_id=eq.${P1_ID}&select=id"; jv 'length')"
  rest "$P2_JWT" GET "nfc_tags?select=*"
  if [[ "$HTTP_CODE" == "200" && "$(jv 'length')" == "0" ]] || [[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
    pass "GET nfc_tags as player -> nothing (HTTP $HTTP_CODE)"
  else
    fail "GET nfc_tags as player leaks rows" "HTTP $HTTP_CODE $(short "$HTTP_BODY")"
  fi
  rest "$P2_JWT" POST "professors" '{"name":"x","display_name":"x","rarity":"COMMON","base_capture_rate":0.5}'
  assert_status_in "POST /rest/v1/professors as player" "401 403"
  rest "$P2_JWT" POST "nfc_tags" "$(json --arg t "${TAG_PREFIX}PLAYER" '{tag_identifier:$t}')"
  assert_status_in "POST /rest/v1/nfc_tags as player" "401 403"
  rest "$P2_JWT" POST "rpc/admin_stats" '{}'
  assert_status_in "rpc admin_stats as player" "401 403"
  rest "$P2_JWT" POST "rpc/collection_progress" "$(json --arg u "$P1_ID" '{p_user:$u}')"
  assert_status_in "rpc collection_progress for another user as player" "401 403"
}

step_12_admin_register_nfc() {
  step "12. admin-register-nfc"
  local body; body=$(json --arg t "$TAG_ADMIN" --arg p "$SEED_PROF1" '{tag_identifier:$t,professor_id:$p,active:true}')
  fn admin-register-nfc "" "$body"
  assert_status "no JWT" 401 UNAUTHORIZED
  fn admin-register-nfc "$P1_JWT" "$body"
  assert_status "as player" 403 FORBIDDEN
  sr GET "nfc_tags?tag_identifier=eq.${TAG_ADMIN}&select=id"
  assert_eq "player attempt created no tag" "0" "$(jv 'length')"
  ADMIN_JWT=$(login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
  [[ -n "$ADMIN_JWT" ]] && pass "admin login" || die "admin login failed ($ADMIN_EMAIL): $(short "$HTTP_BODY")"
  fn admin-register-nfc "$ADMIN_JWT" "$body"
  assert_status "as admin: new tag + professor" 200
  local tag_id; tag_id=$(jv '.tag.id // empty')
  is_uuid "$tag_id" && pass "tag.id is a uuid" || fail "tag.id missing" "$(short "$HTTP_BODY")"
  assert_eq "tag.tag_identifier" "$TAG_ADMIN" "$(jv '.tag.tag_identifier')"
  assert_eq "tag.professor_id" "$SEED_PROF1" "$(jv '.tag.professor_id')"
  assert_true "tag.active" "$(jv '.tag.active')"
  assert_eq "tag.created_at present" "string" "$(jv '.tag.created_at | type')"
  assert_eq "tag has exactly the contract keys" '["active","created_at","id","professor_id","tag_identifier"]' "$(jv '.tag | keys')"
  sr GET "nfc_tags?tag_identifier=eq.${TAG_ADMIN}&select=id,professor_id,active"
  assert_eq "tag row exists" "1" "$(jv 'length')"
  assert_eq "tag row professor_id" "$SEED_PROF1" "$(jv '.[0].professor_id')"
  fn start-encounter "$P2_JWT" "$(json --arg t "$TAG_ADMIN" '{tag_identifier:$t}')"
  assert_status "start-encounter with the new tag while assigned" 200
  assert_eq "…yields professor 1" "$SEED_PROF1" "$(jv '.professor.id')"

  fn admin-register-nfc "$ADMIN_JWT" "$(json --arg t "$TAG_ADMIN" '{tag_identifier:$t,professor_id:null,active:true}')"
  assert_status "same tag again with professor_id null (upsert)" 200
  assert_eq "upsert keeps the same tag.id" "$tag_id" "$(jv '.tag.id')"
  assert_eq "tag.professor_id is null" "null" "$(jv '.tag.professor_id')"
  sr GET "nfc_tags?tag_identifier=eq.${TAG_ADMIN}&select=id,professor_id"
  assert_eq "still one row for the tag" "1" "$(jv 'length')"
  assert_eq "row professor_id is null" "null" "$(jv '.[0].professor_id')"
  fn admin-register-nfc "$ADMIN_JWT" "$(json --arg t "$TAG_ADMIN" '{tag_identifier:$t,professor_id:"ffffffff-ffff-4fff-8fff-ffffffffffff",active:true}')"
  assert_status "unknown professor" 404 PROFESSOR_NOT_FOUND
  fn admin-register-nfc "$ADMIN_JWT" '{"professor_id":null}'
  assert_status "missing tag_identifier" 400 INVALID_INPUT
  fn admin-register-nfc "$ADMIN_JWT" "$(json --arg t "$TAG_ADMIN" '{tag_identifier:$t,professor_id:"nope"}')"
  assert_status "professor_id not a uuid" 400 INVALID_INPUT
  fn admin-register-nfc "$ADMIN_JWT" "$(json --arg t "$TAG_ADMIN" '{tag_identifier:$t,active:"yes"}')"
  assert_status "active not boolean" 400 INVALID_INPUT
  fn start-encounter "$P2_JWT" "$(json --arg t "$TAG_ADMIN" '{tag_identifier:$t}')"
  assert_status "start-encounter with the unassigned tag" 403 PROFESSOR_DISABLED
  fn admin-register-nfc "$ADMIN_JWT" "$(json --arg t "$TAG_ADMIN" --arg p "$SEED_PROF1" '{tag_identifier:$t,professor_id:$p,active:false}')"
  assert_status "same tag, active:false" 200
  assert_eq "tag.active false" "false" "$(jv '.tag.active')"
  fn start-encounter "$P2_JWT" "$(json --arg t "$TAG_ADMIN" '{tag_identifier:$t}')"
  assert_status "start-encounter with the deactivated tag" 403 TAG_DISABLED
  rest "$ADMIN_JWT" GET "nfc_tags?tag_identifier=eq.${TAG_ADMIN}&select=id"
  assert_eq "admin reads nfc_tags via REST (RLS)" "1" "$(jv 'length')"
  rest "$ADMIN_JWT" GET "professors?id=eq.${INACTIVE_PROF_ID}&select=id"
  assert_eq "admin reads inactive professors via REST (RLS)" "1" "$(jv 'length')"
}

step_13_completion() {
  step "13. collection completion with a fresh player"
  signup "$P3_EMAIL" "$PASSWORD" "E2E Player Three $SUFFIX"
  assert_status "signup player 3" 200
  P3_JWT=$(jv '.access_token // empty'); P3_ID=$(jv '.user.id // empty')
  is_uuid "$P3_ID" || die "signup of player 3 failed"

  # Seed professors first (DEMO-TAG-01..08), then any other ACTIVE professor with an
  # active tag (rows other people may have added to the shared stack), so that
  # `completed` can actually be reached: total = all active professors.
  local -a targets=()
  local n line missing
  for n in 1 2 3 4 5 6 7 8; do targets+=("${SEED_PROF_PREFIX}${n} DEMO-TAG-0${n}"); done
  while IFS= read -r line; do [[ -n "$line" ]] && targets+=("$line"); done < <(sql "
    select p.id || ' ' || t.tag_identifier
    from public.professors p
    join lateral (select tag_identifier from public.nfc_tags t
                  where t.professor_id = p.id and t.active order by t.created_at limit 1) t on true
    where p.active and p.id not in (select ('${SEED_PROF_PREFIX}' || g)::uuid from generate_series(1,8) g)
    order by p.id;")
  missing=$(sql "select count(*) from public.professors p where p.active
                 and not exists (select 1 from public.nfc_tags t where t.professor_id = p.id and t.active);")
  assert_eq "every active professor has an active tag (completion reachable)" "0" "$missing"
  (( ${#targets[@]} > 8 )) && echo "         note: ${#targets[@]} active professors on this stack (8 seed + $(( ${#targets[@]} - 8 )) foreign)"

  local pid tag attempts total_attempts=0 got enc last_body="" idx=0 n_skipped=0
  for line in "${targets[@]}"; do
    pid=${line%% *}; tag=${line#* }; idx=$((idx + 1)); attempts=0; got=0
    while (( attempts < MAX_CAPTURE_ATTEMPTS )); do
      attempts=$((attempts + 1))
      fn start-encounter "$P3_JWT" "$(json --arg t "$tag" '{tag_identifier:$t}')"
      if [[ "$HTTP_CODE" == "409" && "$(jv '.error')" == "ALREADY_CAPTURED" ]]; then got=1; break; fi
      if [[ "$HTTP_CODE" != "200" ]]; then
        if (( idx > 8 )) && [[ "$(sql "select count(*) from public.professors p join public.nfc_tags t on t.professor_id = p.id
                                         where p.id = '${pid}' and p.active and t.active and t.tag_identifier = '${tag}';")" == "0" ]]; then
          got=2; break   # foreign row removed/deactivated by someone else meanwhile: no longer counts
        fi
        fail "start-encounter $tag (attempt $attempts)" "HTTP $HTTP_CODE $(short "$HTTP_BODY")"; break
      fi
      enc=$(jv '.encounter_id')
      fn resolve-capture "$P3_JWT" "$(json --arg e "$enc" '{encounter_id:$e,throw_quality:"EXCELLENT"}')"
      if [[ "$HTTP_CODE" != "200" ]]; then fail "resolve-capture $tag (attempt $attempts)" "HTTP $HTTP_CODE $(short "$HTTP_BODY")"; break; fi
      if [[ "$(jv '.success')" == "true" ]]; then
        got=1; last_body=$HTTP_BODY
        [[ "$(jv '.professor_id')" == "$pid" ]] || fail "resolve $tag returned professor $(jv '.professor_id'), expected $pid"
        break
      fi
      [[ "$(jv '.retry_requires_new_nfc_scan')" == "true" ]] || fail "failure body of $tag lacks retry_requires_new_nfc_scan:true"
    done
    total_attempts=$((total_attempts + attempts))
    if (( got == 2 )); then skip "foreign professor ${pid} (${tag}) vanished during the run — no longer part of the collection"; n_skipped=$((n_skipped + 1))
    elif (( got )); then pass "captured ${pid} via ${tag} in ${attempts} attempt(s)"
    else fail "could not capture ${pid} via ${tag} in ${MAX_CAPTURE_ATTEMPTS} attempts"; fi
  done
  echo "         ${#targets[@]} professors, ${total_attempts} encounters in total"
  HTTP_BODY=$last_body
  local n_targets=$(( ${#targets[@]} - n_skipped ))
  assert_eq "last success response: collection.captured" "$n_targets" "$(jv '.collection.captured')"
  assert_eq "last success response: collection.total" "$n_targets" "$(jv '.collection.total')"
  assert_true "last success response: collection.completed" "$(jv '.collection.completed')"
  sr GET "profiles?id=eq.${P3_ID}&select=collection_completed_at"
  assert_eq "profiles.collection_completed_at is set" "string" "$(jv '.[0].collection_completed_at | type')"
  rest "$P3_JWT" POST "rpc/collection_progress" '{}'
  assert_status "rpc collection_progress as player 3" 200
  assert_eq "collection_progress.captured" "$n_targets" "$(jv '.captured')"
  assert_eq "collection_progress.total" "$n_targets" "$(jv '.total')"
  assert_true "collection_progress.completed" "$(jv '.completed')"
  rest "$P1_JWT" POST "rpc/collection_progress" '{}'
  assert_eq "collection_progress for player 1 -> captured 2, not completed" "2 false" "$(jv '"\(.captured) \(.completed)"')"
  rest "$ADMIN_JWT" POST "rpc/admin_stats" '{}'
  assert_status "rpc admin_stats as admin" 200
  local cc; cc=$(jv '.completed_collections // 0')
  (( cc >= 1 )) && pass "admin_stats.completed_collections >= 1 ($cc)" || fail "admin_stats.completed_collections < 1" "$(short "$HTTP_BODY")"
  assert_eq "admin_stats has the contract keys" '["active_professors","completed_collections","total_captures","total_players"]' "$(jv 'keys')"
  rest "$ADMIN_JWT" POST "rpc/collection_progress" "$(json --arg u "$P3_ID" '{p_user:$u}')"
  assert_true "admin can query collection_progress of another user" "$(jv '.completed')"
}

step_14_logs() {
  step "14. structured logs (no secrets)"
  if [[ -z "$LOG_SOURCE" ]]; then
    skip "no functions log available (set FUNCTIONS_LOG=<file> or run with docker access) — step skipped"
    return
  fi
  local log="$TMP/functions.log"
  read_log >"$log" 2>/dev/null || { fail "could not read the functions log"; return; }
  echo "         source: $LOG_SOURCE, $(wc -l <"$log") lines"
  local ev
  for ev in encounter_started capture_resolved invalid_tag; do
    grep -q "\"event\":\"$ev\"" "$log" && pass "log contains event $ev" || fail "log has no event $ev"
  done
  grep -q "\"event\":\"encounter_started\".*\"encounter_id\":\"$ENC1\"" "$log" \
    && pass "encounter_started logged for encounter $ENC1" || fail "encounter_started for $ENC1 not found"
  grep -q "\"event\":\"capture_resolved\".*\"encounter_id\":\"$ENC_SUCCESS_ID\".*\"success\":true" "$log" \
    && pass "capture_resolved success:true logged for $ENC_SUCCESS_ID" || fail "capture_resolved success for $ENC_SUCCESS_ID not found"
  grep -q "\"event\":\"capture_resolved\".*\"encounter_id\":\"$ENC_FAILED_ID\".*\"success\":false" "$log" \
    && pass "capture_resolved success:false logged for $ENC_FAILED_ID" || fail "capture_resolved failure for $ENC_FAILED_ID not found"
  grep -q "\"event\":\"invalid_tag\".*\"tag_identifier\":\"$TAG_UNKNOWN\"" "$log" \
    && pass "invalid_tag logged for $TAG_UNKNOWN" || fail "invalid_tag for $TAG_UNKNOWN not found"
  grep -q "\"event\":\"nfc_tag_registered\".*\"tag_identifier\":\"$TAG_ADMIN\"" "$log" \
    && pass "nfc_tag_registered logged for $TAG_ADMIN" || fail "nfc_tag_registered for $TAG_ADMIN not found"
  local bad
  bad=$(grep -o '{"ts":.*' "$log" | jq -c '.' 2>&1 >/dev/null | head -1)
  [[ -z "$bad" ]] && pass "every event line is valid single-line JSON" || fail "invalid JSON event line" "$bad"
  local jwt_hits; jwt_hits=$(grep -Ec 'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+' "$log")
  assert_eq "no JWT-looking string in the log" "0" "$jwt_hits"
  ! grep -qF -- "$P1_JWT" "$log" && pass "player JWT not in the log" || fail "player JWT found in the log"
  ! grep -qF -- "$ANON_KEY" "$log" && pass "anon key not in the log" || fail "anon key found in the log"
  ! grep -qF -- "$SERVICE_ROLE_KEY" "$log" && pass "service_role key not in the log" || fail "service_role key found in the log"
  ! grep -qF -- "$PASSWORD" "$log" && pass "test password not in the log" || fail "test password found in the log"
  ! grep -qF -- "$ADMIN_PASSWORD" "$log" && pass "admin password not in the log" || fail "admin password found in the log"
  local leaked
  leaked=$(grep -Eio '"(authorization|password|token|jwt|secret|api[_-]?key|service[_-]?role[a-z_]*)":"[^"]*"' "$log" \
             | grep -Fv '"[redacted]"' | head -3 | tr '\n' ' ')
  [[ -z "$leaked" ]] && pass "no unredacted secret-looking keys in event lines" \
    || fail "secret-looking key with a value in the log" "$leaked"
}

step_15_cleanup() {
  step "15. cleanup + seed integrity"
  if [[ "${E2E_KEEP:-0}" == "1" ]]; then
    skip "E2E_KEEP=1 — rows with suffix '$SUFFIX' kept"
  else
    cleanup_rows && pass "deleted users/professors/tags with suffix '$SUFFIX'" || fail "cleanup via psql failed"
    assert_eq "no leftover auth.users" "0" "$(sql "select count(*) from auth.users where email like '${EMAIL_PREFIX}%';")"
    assert_eq "no leftover profiles" "0" "$(sql "select count(*) from public.profiles where email like '${EMAIL_PREFIX}%';")"
    assert_eq "no leftover encounters (cascade)" "0" "$(sql "select count(*) from public.encounters e where not exists (select 1 from public.profiles p where p.id = e.user_id);")"
    assert_eq "no leftover captures (cascade)" "0" "$(sql "select count(*) from public.captures c where not exists (select 1 from public.profiles p where p.id = c.user_id);")"
    assert_eq "no leftover nfc_tags" "0" "$(sql "select count(*) from public.nfc_tags where tag_identifier like '${TAG_PREFIX}%';")"
    assert_eq "no leftover professors" "0" "$(sql "select count(*) from public.professors where name like '${PROF_NAME_PREFIX}%';")"
  fi
  assert_eq "8 seed professors present and active" "8" \
    "$(sql "select count(*) from public.professors where active and id in (select ('${SEED_PROF_PREFIX}' || g)::uuid from generate_series(1,8) g);")"
  assert_eq "8 seed tags DEMO-TAG-01..08 present, active and mapped" "8" \
    "$(sql "select count(*) from public.nfc_tags where tag_identifier ~ '^DEMO-TAG-0[1-8]$' and active
            and professor_id = ('${SEED_PROF_PREFIX}' || right(tag_identifier, 1))::uuid;")"
  assert_eq "seed demo users present" "2" \
    "$(sql "select count(*) from public.profiles where email in ('admin@profesorgo.local','player@profesorgo.local');")"
  assert_eq "app_settings seed rows present" "2" \
    "$(sql "select count(*) from public.app_settings where key in ('encounter_expiration_seconds','throw_bonus');")"
  echo "         totals now: professors=$(sql 'select count(*) from public.professors;') nfc_tags=$(sql 'select count(*) from public.nfc_tags;') profiles=$(sql 'select count(*) from public.profiles;')"
}

# ============================================================================
main() {
  echo "Profesor GO — e2e against the live local stack"
  load_config
  preflight
  step_1_signup
  step_2_reads
  step_3_start_encounter_errors
  step_4_start_encounter_ok
  step_5_resolve_miss
  step_6_resolve_excellent
  step_7_wrong_user
  step_8_expiry
  step_9_resolve_input_errors
  step_10_concurrency
  step_11_player_writes
  step_12_admin_register_nfc
  step_13_completion
  step_14_logs
  step_15_cleanup

  printf '\n== Summary ==\n%d passed, %d failed, %d skipped\n' "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
  if (( FAIL_COUNT > 0 )); then
    printf 'Failed checks:\n'; printf '  - %s\n' "${FAILED[@]}"
    exit 1
  fi
  echo "ALL PASS"
  exit 0
}
main "$@"
