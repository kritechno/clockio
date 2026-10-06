#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Clockio.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c release --product Clockio

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/Clockio" "$MACOS_DIR/Clockio"
if [[ -f "$ROOT_DIR/build/icon.icns" ]]; then
  cp "$ROOT_DIR/build/icon.icns" "$RESOURCES_DIR/Clockio.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Clockio</string>
  <key>CFBundleExecutable</key>
  <string>Clockio</string>
  <key>CFBundleIconFile</key>
  <string>Clockio</string>
  <key>CFBundleIdentifier</key>
  <string>com.clockio.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Clockio</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.0</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Clockio uses your approximate location to show the current local temperature and to follow your local sunset and sunrise for automatic day/night.</string>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>Clockio shows today's events from your Calendar (including Google calendars added to macOS) alongside your to-do list.</string>
  <key>NSCalendarsUsageDescription</key>
  <string>Clockio shows today's events from your Calendar (including Google calendars added to macOS) alongside your to-do list.</string>
</dict>
</plist>
PLIST

chmod +x "$MACOS_DIR/Clockio"
echo "$APP_DIR"
