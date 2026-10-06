#!/bin/bash
# Full Xcode works directly. Recent CLT releases ship Testing as a framework,
# but omit its Foundation overlay; these tests do not need that overlay.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
DEVELOPER_DIR_PATH="$(xcode-select -p)"
FRAMEWORKS="$DEVELOPER_DIR_PATH/Library/Developer/Frameworks"
if [[ "$DEVELOPER_DIR_PATH" == */CommandLineTools && -d "$FRAMEWORKS/Testing.framework" ]]; then
    exec swift test --disable-xctest \
        -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
        -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
        -Xlinker -rpath -Xlinker "$FRAMEWORKS" "$@"
fi
exec swift test "$@"
