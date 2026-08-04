#!/bin/bash
# Generates iOS app icons for Workouts from assets/icons/base_icon_img.png
# Usage: ./scripts/generate_icon.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_ICON="$ROOT_DIR/assets/icons/base_icon_img.png"
ICONSET="$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$BASE_ICON" ]]; then
  echo "Missing base icon: $BASE_ICON" >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick (magick) is required" >&2
  exit 1
fi

mkdir -p "$ICONSET"

echo "Generating iOS app icons from $BASE_ICON..."

magick "$BASE_ICON" -resize 1024x1024 "$ICONSET/Icon-App-1024x1024@1x.png"

magick "$BASE_ICON" -resize 40x40   "$ICONSET/Icon-App-20x20@2x.png"
magick "$BASE_ICON" -resize 60x60   "$ICONSET/Icon-App-20x20@3x.png"
magick "$BASE_ICON" -resize 29x29   "$ICONSET/Icon-App-29x29@1x.png"
magick "$BASE_ICON" -resize 58x58   "$ICONSET/Icon-App-29x29@2x.png"
magick "$BASE_ICON" -resize 87x87   "$ICONSET/Icon-App-29x29@3x.png"
magick "$BASE_ICON" -resize 80x80   "$ICONSET/Icon-App-40x40@2x.png"
magick "$BASE_ICON" -resize 120x120 "$ICONSET/Icon-App-40x40@3x.png"
magick "$BASE_ICON" -resize 120x120 "$ICONSET/Icon-App-60x60@2x.png"
magick "$BASE_ICON" -resize 180x180 "$ICONSET/Icon-App-60x60@3x.png"

magick "$BASE_ICON" -resize 20x20   "$ICONSET/Icon-App-20x20@1x.png"
magick "$BASE_ICON" -resize 40x40   "$ICONSET/Icon-App-40x40@1x.png"
magick "$BASE_ICON" -resize 76x76   "$ICONSET/Icon-App-76x76@1x.png"
magick "$BASE_ICON" -resize 152x152 "$ICONSET/Icon-App-76x76@2x.png"
magick "$BASE_ICON" -resize 167x167 "$ICONSET/Icon-App-83.5x83.5@2x.png"

echo "All iOS app icons generated successfully!"
echo "Icons saved to: $ICONSET"
