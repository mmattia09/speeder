#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/Speeder.app"
[[ -d "$APP" ]] || { echo 'Build the app first with Scripts/build-app.sh release universal'; exit 1; }
STAGING="$(mktemp -d -t speeder-dmg)"
trap 'rm -rf "$STAGING"' EXIT
 ditto "$APP" "$STAGING/Speeder.app"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/Install.txt" <<'TEXT'
Drag Speeder.app to Applications, then open it from Applications.
Trascina Speeder.app in Applicazioni, poi aprila da Applicazioni.

macOS 13 or later. Enable Accessibility when prompted to track typing.
TEXT
hdiutil create -volname Speeder -srcfolder "$STAGING" -ov -format UDZO "$ROOT/dist/Speeder.dmg"
hdiutil verify "$ROOT/dist/Speeder.dmg"
