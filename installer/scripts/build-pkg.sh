#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
OUT_DIR="$ROOT_DIR/dist"
PKG_SCRIPTS_DIR="$OUT_DIR/pkg-scripts"
VERSION="${VERSION:-1.0.0}"
PKG_ID="${PKG_ID:-com.aiden.mac}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
TRAY_BUNDLE_ID="${TRAY_BUNDLE_ID:-com.aiden.traymac}"

PAYLOAD_DIR="$OUT_DIR/payload"
TRAY_APP_DIR="$PAYLOAD_DIR/Applications/AidenTrayMac.app"
TRAY_MACOS_DIR="$TRAY_APP_DIR/Contents/MacOS"
TRAY_RES_DIR="$TRAY_APP_DIR/Contents/Resources"
BOOTSTRAP_DIR="$PAYLOAD_DIR/Library/Application Support/Aiden/bootstrap"

rm -rf "$OUT_DIR"
mkdir -p "$TRAY_MACOS_DIR" "$TRAY_RES_DIR" "$BOOTSTRAP_DIR"
mkdir -p "$PKG_SCRIPTS_DIR/manifests" "$PKG_SCRIPTS_DIR/third_party/collector"

# Build each product explicitly for compatibility across SwiftPM versions.
swift build -c release --product AidenRuntimeAgent
swift build -c release --product AidenTrayMac

if [[ ! -x "$BUILD_DIR/AidenRuntimeAgent" ]]; then
  echo "[ERROR] Missing built binary: $BUILD_DIR/AidenRuntimeAgent" >&2
  exit 1
fi

if [[ ! -x "$BUILD_DIR/AidenTrayMac" ]]; then
  echo "[ERROR] Missing built binary: $BUILD_DIR/AidenTrayMac" >&2
  exit 1
fi

cp "$BUILD_DIR/AidenTrayMac" "$TRAY_MACOS_DIR/AidenTrayMac"
cp "$BUILD_DIR/AidenRuntimeAgent" "$BOOTSTRAP_DIR/AidenRuntimeAgent"
chmod 755 "$TRAY_MACOS_DIR/AidenTrayMac" "$BOOTSTRAP_DIR/AidenRuntimeAgent"

cat > "$TRAY_APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>AidenTrayMac</string>
  <key>CFBundleDisplayName</key>
  <string>Aiden Tray</string>
  <key>CFBundleIdentifier</key>
  <string>${TRAY_BUNDLE_ID}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleExecutable</key>
  <string>AidenTrayMac</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -n "$APP_SIGN_IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --sign "$APP_SIGN_IDENTITY" "$BOOTSTRAP_DIR/AidenRuntimeAgent"
  codesign --force --options runtime --timestamp --sign "$APP_SIGN_IDENTITY" "$TRAY_APP_DIR"
  codesign --verify --deep --strict --verbose=2 "$TRAY_APP_DIR"
  codesign --verify --verbose=2 "$BOOTSTRAP_DIR/AidenRuntimeAgent"
fi

cp "$ROOT_DIR/installer/scripts/postinstall" "$PKG_SCRIPTS_DIR/postinstall"
cp "$ROOT_DIR/installer/scripts/preuninstall" "$PKG_SCRIPTS_DIR/preuninstall"
cp "$ROOT_DIR/installer/manifests/dependency-lock.json" "$PKG_SCRIPTS_DIR/manifests/dependency-lock.json"
cp "$ROOT_DIR/installer/manifests/com.aiden.runtimeagent.plist" "$PKG_SCRIPTS_DIR/manifests/com.aiden.runtimeagent.plist"
cp "$ROOT_DIR/installer/manifests/com.aiden.tray.plist" "$PKG_SCRIPTS_DIR/manifests/com.aiden.tray.plist"
cp "$ROOT_DIR/third_party/collector/config.yaml.template" "$PKG_SCRIPTS_DIR/third_party/collector/config.yaml.template"
chmod 755 "$PKG_SCRIPTS_DIR/postinstall" "$PKG_SCRIPTS_DIR/preuninstall"

pkgbuild \
  --root "$PAYLOAD_DIR" \
  --identifier "$PKG_ID" \
  --version "$VERSION" \
  --scripts "$PKG_SCRIPTS_DIR" \
  "$OUT_DIR/AidenMac-unsigned.pkg"

echo "Package ID: $PKG_ID"
echo "Version: $VERSION"
echo "Tray app path in payload: $TRAY_APP_DIR"
echo "Agent bootstrap path in payload: $BOOTSTRAP_DIR/AidenRuntimeAgent"
echo "Generated: $OUT_DIR/AidenMac-unsigned.pkg"
