#!/usr/bin/env bash
# One-shot local setup: checks tools and installs dependencies for all three projects.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v psql >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
  LIBPQ_PREFIX="$(brew --prefix libpq 2>/dev/null)" || LIBPQ_PREFIX=""
  if [[ -n "$LIBPQ_PREFIX" && -x "$LIBPQ_PREFIX/bin/psql" ]]; then
    export PATH="$LIBPQ_PREFIX/bin:$PATH"
  fi
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "✗ falta $1 — $2"; return 1; }; echo "✓ $1 $($1 --version 2>/dev/null | head -1)"; }
echo "== Comprobando herramientas =="
need flutter  "https://docs.flutter.dev/get-started/install" || true
need node     "https://nodejs.org (20 LTS)"                   || true
need deno     "https://deno.land"                             || true
need supabase "https://supabase.com/docs/guides/cli"          || true
need docker   "https://docs.docker.com/get-docker/"           || true
need jq       "https://jqlang.github.io/jq/download/"        || true
need psql     "PostgreSQL client (en macOS: brew install libpq)" || true

echo; echo "== Mobile: flutter pub get =="
( cd "$ROOT/apps/mobile" && flutter pub get ) || echo "(omitido: flutter no disponible)"

echo; echo "== Admin: npm install =="
( cd "$ROOT/apps/admin" && npm install ) || echo "(omitido: npm no disponible)"

echo; echo "== Env files =="
[ -f "$ROOT/apps/mobile/.env" ]       || cp "$ROOT/apps/mobile/.env.example" "$ROOT/apps/mobile/.env" 2>/dev/null || true
[ -f "$ROOT/apps/admin/.env.local" ]  || cp "$ROOT/apps/admin/.env.example" "$ROOT/apps/admin/.env.local" 2>/dev/null || true

cat <<MSG

Listo. Siguientes pasos:
  supabase start && supabase db reset      # backend local
  supabase status -o env                   # copia las claves en apps/mobile/.env y apps/admin/.env.local
  cd apps/mobile && flutter run            # app en modo demo
  cd apps/admin && npm run dev             # panel admin
MSG
