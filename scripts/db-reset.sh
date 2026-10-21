#!/usr/bin/env bash
# Recreate the local database: drops everything, re-applies supabase/migrations/*.sql
# and loads supabase/seed.sql. Requires a running stack (scripts/supabase-start.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/tools/bin:$PATH"
exec supabase db reset --yes "$@"
