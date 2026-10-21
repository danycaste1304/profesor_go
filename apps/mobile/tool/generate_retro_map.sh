#!/usr/bin/env bash
set -euo pipefail
MOBILE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v rsvg-convert >/dev/null 2>&1 || {
  echo "Install librsvg (macOS: brew install librsvg) to generate the map." >&2
  exit 1
}
rsvg-convert --width 450 --height 600 \
  --output "$MOBILE_ROOT/assets/map/campus_map.png" \
  "$MOBILE_ROOT/assets/map/campus_map.svg"
echo "Retro campus map regenerated."
