#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$repo_root/apps/mobile/.env"

if [[ ! -f "$env_file" ]]; then
  echo "Falta apps/mobile/.env con DEMO_MODE=false y las claves públicas de Supabase." >&2
  exit 1
fi

read_value() {
  sed -n "s/^$1=//p" "$env_file" | tail -n 1 | tr -d '\r'
}

demo_mode="$(read_value DEMO_MODE)"
supabase_url="$(read_value SUPABASE_URL)"
anon_key="$(read_value SUPABASE_ANON_KEY)"

if [[ "$demo_mode" != "false" ]]; then
  echo "La build real exige DEMO_MODE=false en apps/mobile/.env." >&2
  exit 1
fi
if [[ "$supabase_url" != https://* ]]; then
  echo "La build release real exige SUPABASE_URL con HTTPS." >&2
  exit 1
fi
if [[ -z "$anon_key" || "$anon_key" == replace-with-* ]]; then
  echo "Falta SUPABASE_ANON_KEY (clave pública) en apps/mobile/.env." >&2
  exit 1
fi

cd "$repo_root/apps/mobile"
flutter build apk --release --dart-define-from-file=.env
mkdir -p build/real-android
cp build/app/outputs/flutter-apk/app-release.apk build/real-android/profesor-go-real.apk
echo "APK real: $repo_root/apps/mobile/build/real-android/profesor-go-real.apk"
