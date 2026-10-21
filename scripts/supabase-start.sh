#!/usr/bin/env bash
# Start the local Supabase stack (API :54321, DB :54322, Studio :54323) and print
# the connection variables (SUPABASE_URL, ANON_KEY, SERVICE_ROLE_KEY, ...) in env format.
# Copy ANON_KEY into apps/mobile/.env and apps/admin/.env.local (see .env.example).
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/tools/bin:$PATH"
supabase start --yes "$@"
echo
echo "# Local Supabase is running. Keys (local dev only):"
supabase status -o env
