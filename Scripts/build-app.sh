#!/bin/bash
#
# Builds Speeder.app in dist/ for local, unsigned use.
#
# A bundle (rather than `swift run`) matters for two reasons: the app shows up as
# a real, clickable entry in System Settings → Privacy & Security → Accessibility,
# and it can be launched from Finder like any other app.
#
# Usage: Scripts/build-app.sh [debug|release]

set -euo pipefail

CONFIGURATION="${1:-release}"
case "$CONFIGURATION" in
    debug|release) ;;
    *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;;
esac
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/Speeder.app"
CONTENTS="$APP/Contents"

cd "$ROOT"
swift build -c "$CONFIGURATION" --product Speeder
BINARY="$(swift build -c "$CONFIGURATION" --show-bin-path)/Speeder"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BINARY" "$CONTENTS/MacOS/Speeder"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Speeder</string>
    <key>CFBundleIdentifier</key>
    <string>com.mmattia09.speeder</string>
    <key>CFBundleName</key>
    <string>Speeder</string>
    <key>CFBundleDisplayName</key>
    <string>Speeder</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc signature for local runs. Rebuilds may require reauthorizing the app.
codesign --force --sign - "$APP" >/dev/null 2>&1 || \
    echo "warning: ad-hoc signing failed; the app still runs but macOS may re-prompt for permissions" >&2

echo "Built $APP"
echo "Grant Accessibility access there, or from the app's menu: Open Accessibility Settings…"
