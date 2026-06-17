#!/bin/bash
# Builds PortPilot and packages it into a desktop + menu-bar .app bundle.
# Usage: ./scripts/build-app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="PortPilot.app"
BIN="PortPilot"
TARGET="arm64-apple-macosx13.0"

echo "▶ Compiling..."
swiftc -O -target "$TARGET" -o "$BIN" Sources/PortPilot/*.swift \
    -framework SwiftUI -framework AppKit

echo "▶ Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$BIN" "$APP/Contents/MacOS/PortPilot"
cp scripts/Info.plist "$APP/Contents/Info.plist"
if [ -f scripts/AppIcon.icns ]; then
    cp scripts/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc codesign so macOS lets it run locally.
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "✅ Built $ROOT/$APP"
echo "   Run it:        open $APP"
echo "   Install it:    cp -R $APP /Applications/"
