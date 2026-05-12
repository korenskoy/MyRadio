#!/usr/bin/env bash
# build-dmg.sh — bumps build number, builds MyRadio in Release, packages as DMG
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SCHEME="MyRadio"
PROJECT="MyRadio.xcodeproj"
CONFIG="Release"
DERIVED="build"
APP_NAME="MyRadio"
DIST_DIR="dist"
VOLUME_NAME="MyRadio"

# ── Resolve project root (script may be called from anywhere) ─────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

# ── Auto-increment build number ───────────────────────────────────────────────
XCCONFIG="$ROOT/Configuration/Version.xcconfig"
BUILD=$(grep "^CURRENT_PROJECT_VERSION" "$XCCONFIG" | awk -F'= *' '{print $2}' | xargs)
NEW_BUILD=$((BUILD + 1))
sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD/" "$XCCONFIG"
echo "▸ Build number: $BUILD → $NEW_BUILD"

VERSION=$(grep "^MARKETING_VERSION" "$XCCONFIG" | awk -F'= *' '{print $2}' | xargs)
echo "▸ Version: $VERSION ($NEW_BUILD)"

# ── Build ─────────────────────────────────────────────────────────────────────
echo "▸ Building $SCHEME ($CONFIG)…"
if command -v xcpretty &>/dev/null; then
  xcodebuild \
    -project "$PROJECT" \
    -scheme  "$SCHEME"  \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED" \
    -destination "platform=macOS" \
    build 2>&1 | xcpretty
else
  xcodebuild \
    -project "$PROJECT" \
    -scheme  "$SCHEME"  \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED" \
    -destination "platform=macOS" \
    build
fi

APP_PATH="$ROOT/$DERIVED/Build/Products/$CONFIG/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "✗ App not found at $APP_PATH — build may have failed."
  exit 1
fi

# ── Prepare staging folder ────────────────────────────────────────────────────
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# ── Create compressed DMG ─────────────────────────────────────────────────────
mkdir -p "$ROOT/$DIST_DIR"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$ROOT/$DIST_DIR/$DMG_NAME"

echo "▸ Creating DMG…"
hdiutil create \
  -volname  "$VOLUME_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format   UDZO \
  -fs       HFS+ \
  "$DMG_PATH"

SIZE=$(du -sh "$DMG_PATH" | cut -f1)
echo "✓ $DMG_NAME  ($SIZE)  →  $DIST_DIR/"
