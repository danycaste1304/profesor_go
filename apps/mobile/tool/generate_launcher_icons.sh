#!/usr/bin/env bash
# Regenerate the platform launcher icons from the original SVG artwork.
set -euo pipefail

MOBILE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$MOBILE_ROOT/assets/branding/launcher_icon.svg"
ANDROID_RES="$MOBILE_ROOT/android/app/src/main/res"
IOS_SET="$MOBILE_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
ADMIN_PUBLIC="$MOBILE_ROOT/../admin/public"

command -v rsvg-convert >/dev/null 2>&1 || {
  echo "Install librsvg (macOS: brew install librsvg) to generate icons." >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "Install jq to read the iOS icon manifest." >&2
  exit 1
}

for item in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  density="${item%%:*}"
  pixels="${item##*:}"
  rsvg-convert --width "$pixels" --height "$pixels" \
    --output "$ANDROID_RES/mipmap-$density/ic_launcher.png" "$SOURCE"
done

while IFS=$'\t' read -r filename pixels; do
  rsvg-convert --width "$pixels" --height "$pixels" \
    --output "$IOS_SET/$filename" "$SOURCE"
done < <(jq -r '.images[] | [.filename, ((.size | split("x")[0] | tonumber) * (.scale | sub("x$"; "") | tonumber) | round)] | @tsv' "$IOS_SET/Contents.json")

rsvg-convert --width 512 --height 512 \
  --output "$MOBILE_ROOT/assets/branding/launcher_icon.png" "$SOURCE"
cp "$SOURCE" "$ADMIN_PUBLIC/profesor-go-icon.svg"
echo "Launcher icons regenerated for Android, iOS and admin."
