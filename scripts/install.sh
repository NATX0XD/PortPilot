#!/bin/bash
# Builds PortPilot, installs it to /Applications, and sets it to auto-start at login.
# Usage: ./scripts/install.sh   (no sudo needed for admin users)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 1. Build a fresh .app
"$ROOT/scripts/build-app.sh"

# 2. Install into /Applications (fall back to ~/Applications if not writable)
DEST="/Applications"
if [ ! -w "$DEST" ]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
    echo "ℹ /Applications not writable — installing to $DEST instead"
fi
# Quit any running copy so we can overwrite it.
pkill -f "PortPilot.app/Contents/MacOS/PortPilot" 2>/dev/null || true
sleep 1
rm -rf "$DEST/PortPilot.app"
cp -R "$ROOT/PortPilot.app" "$DEST/"
APP_BIN="$DEST/PortPilot.app/Contents/MacOS/PortPilot"
echo "✅ Installed to $DEST/PortPilot.app"

# 3. LaunchAgent so it starts automatically at every login
PLIST="$HOME/Library/LaunchAgents/com.portpilot.app.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.portpilot.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
PLISTEOF

# (Re)load it.
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST"
echo "✅ Auto-start at login enabled ($PLIST)"

# 4. Launch it now.
open "$DEST/PortPilot.app"
echo "🚀 PortPilot is running — look for the 📡 icon in the menu bar."
echo ""
echo "To uninstall later:"
echo "  launchctl unload \"$PLIST\" && rm \"$PLIST\" && rm -rf \"$DEST/PortPilot.app\""
