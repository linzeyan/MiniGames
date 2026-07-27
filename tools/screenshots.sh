#!/bin/bash
# Capture App Store screenshots on the 6.9" iPhone simulator.
#
# App Store Connect only requires the 6.9" iPhone set (1320x2868); the smaller
# sizes are scaled from it. Uses the app's own debug launch arguments so each
# gameplay shot lands mid-run instead of on an empty first frame.
#
# Usage: tools/screenshots.sh [output-dir]
set -euo pipefail

DEVICE="iPhone 17 Pro Max"
BUNDLE_ID="com.zeyanlin.smallgame"
APP="build/Build/Products/Debug-iphonesimulator/SmallGame.app"
OUT="${1:-build/screenshots}"

# Seconds of autoplay before the shutter — long enough for the scene to fill
# with platforms / fish / enemies and for a score to appear.
SETTLE=12

[ -d "$APP" ] || { echo "Build first: make build" >&2; exit 1; }
mkdir -p "$OUT"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" >/dev/null
xcrun simctl install "$DEVICE" "$APP"

shoot() {
    local name="$1"; shift
    xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$DEVICE" "$BUNDLE_ID" "$@" >/dev/null
    sleep "$SETTLE"
    xcrun simctl io "$DEVICE" screenshot --type=png "$OUT/$name.png" 2>/dev/null
    echo "  $name.png"
}

echo "Capturing to $OUT ..."
shoot 01-menu
shoot 02-tower    -autoplay tower    -tutorial.seen.tower YES
shoot 03-shaft    -autoplay shaft    -tutorial.seen.shaft YES
shoot 04-fishing  -autoplay fishing  -tutorial.seen.fishing YES
shoot 05-snowball -autoplay snowball -tutorial.seen.snowball YES
shoot 06-settings -showSettings YES

echo "Done. Review every shot before uploading — autoplay is a bot, not a demo."
