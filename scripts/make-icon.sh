#!/bin/bash
# Generates scripts/AppIcon.icns from the CoreGraphics renderer.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp -d)"
swift scripts/make-icon.swift "$TMP/icon_1024.png"

ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d "$TMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
cp "$TMP/icon_1024.png" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o scripts/AppIcon.icns
rm -rf "$TMP"
echo "✅ scripts/AppIcon.icns"
