#!/bin/bash
# Cut a release locally: bump version, build, zip, tag, and publish to GitHub Releases.
# Usage: ./scripts/release.sh 1.0.1
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then echo "usage: ./scripts/release.sh <version>   e.g. 1.0.1"; exit 1; fi
TAG="v$VERSION"

echo "▶ Setting version $VERSION in Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" scripts/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" scripts/Info.plist

echo "▶ Building"
./scripts/build-app.sh >/dev/null

echo "▶ Zipping"
ZIP="$ROOT/PortPilot-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent PortPilot.app "$ZIP"

# Commit the version bump if we're in a git repo with changes.
if git rev-parse --git-dir >/dev/null 2>&1; then
    git add scripts/Info.plist 2>/dev/null || true
    git commit -m "Release $TAG" >/dev/null 2>&1 && git push origin HEAD >/dev/null 2>&1 || echo "  (no version change to commit)"
fi

ASSET="$ZIP#PortPilot.app ($VERSION, Apple Silicon)"
if gh release view "$TAG" >/dev/null 2>&1; then
    echo "▶ Updating existing release $TAG"
    gh release upload "$TAG" "$ASSET" --clobber
else
    echo "▶ Creating release $TAG"
    gh release create "$TAG" "$ASSET" --title "PortPilot $TAG" --generate-notes
fi

echo "✅ Released $TAG → https://github.com/NATX0XD/PortPilot/releases/tag/$TAG"
