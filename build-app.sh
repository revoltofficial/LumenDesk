#!/bin/zsh
set -euo pipefail
LUMENDESK_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$LUMENDESK_ROOT"
swift test
swift build -c release
LUMENDESK_BIN="$(swift build -c release --show-bin-path)"
mkdir -p dist/LumenDesk.app/Contents/MacOS
cp "$LUMENDESK_BIN/LumenDesk" dist/LumenDesk.app/Contents/MacOS/LumenDesk
cp Info.plist dist/LumenDesk.app/Contents/Info.plist
codesign --force --sign - dist/LumenDesk.app
echo "Built $LUMENDESK_ROOT/dist/LumenDesk.app"
