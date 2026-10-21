#!/usr/bin/env bash
# Runs every quality gate the CI runs. Fails fast on the first error.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== Mobile ==";  ( cd "$ROOT/apps/mobile" && flutter analyze && flutter test )
echo "== Admin ==";   ( cd "$ROOT/apps/admin"  && npm run lint && npm run typecheck && npm test && npm run build )
echo "== Edge ==";    ( cd "$ROOT/supabase/functions" && deno task check && deno task lint && deno task test )
if supabase status >/dev/null 2>&1; then
  echo "== DB =="; ( cd "$ROOT" && supabase test db )
  if curl -s -o /dev/null --max-time 3 -X POST "http://127.0.0.1:54321/functions/v1/start-encounter"; then
    echo "== E2E =="; "$ROOT/scripts/e2e-local.sh"
  else
    echo "== E2E == (omitido: ejecuta 'supabase functions serve --no-verify-jwt')"
  fi
else
  echo "== DB/E2E == (omitido: ejecuta 'supabase start' para correr los tests pgTAP y el e2e)"
fi
echo "✓ todo en verde"
