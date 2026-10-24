#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mobile_dir="$repo_root/apps/mobile"

cd "$mobile_dir"
PROFESOR_GO_NFC_DIAGNOSTIC=1 flutter build apk --release --target lib/nfc_diagnostic_main.dart
mkdir -p build/nfc-diagnostic
cp build/app/outputs/flutter-apk/app-release.apk \
  build/nfc-diagnostic/profesor-go-nfc-diagnostico.apk
echo "APK de diagnóstico: $mobile_dir/build/nfc-diagnostic/profesor-go-nfc-diagnostico.apk"
