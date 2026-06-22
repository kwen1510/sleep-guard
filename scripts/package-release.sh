#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Codex Sleep Guard"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/dist/Codex-Sleep-Guard-macOS.zip"
BUILD_DIR="$ROOT_DIR/Build"

cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install with: brew install xcodegen" >&2
  exit 1
fi

rm -rf "$BUILD_DIR" "$APP_BUNDLE" "$ZIP_PATH"
mkdir -p "$ROOT_DIR/dist"

xcodegen generate
xcodebuild \
  -project CodexSleepGuard.xcodeproj \
  -scheme CodexSleepGuard \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  build \
  CODE_SIGNING_ALLOWED=NO

ditto "$BUILD_DIR/Build/Products/Release/$APP_NAME.app" "$APP_BUNDLE"

codesign --force --sign - "$APP_BUNDLE/Contents/Frameworks/CodexSleepGuardCore.framework"
codesign --force --sign - --identifier com.codexsleepguard.app.PowerHelper "$APP_BUNDLE/Contents/MacOS/com.codexsleepguard.app.PowerHelper"
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=4 "$APP_BUNDLE"

ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Created $ZIP_PATH"

