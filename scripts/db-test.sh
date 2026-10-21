#!/usr/bin/env bash
# Run the pgTAP suite in supabase/tests/ against the running local stack.
# Pass --reset to reload migrations + seed first.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/tools/bin:$PATH"
if [[ "${1:-}" == "--reset" ]]; then
  shift
  supabase db reset --yes
fi
exec supabase test db "$@"
