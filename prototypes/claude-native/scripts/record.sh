#!/usr/bin/env bash
# Boots the iPhone Duo simulator, applies a clean status bar, launches Burrow in -recording
# mode, and records the screen until Ctrl+C.
#
# Note: simctl recordVideo captures the screen only (no device frame, no audio). For the hero
# shot where the fold is visible, screen-record the Device Hub window with Cmd-Shift-5 instead
# and use this script just for the status bar + launch (pass --no-video).
#
# Usage: scripts/record.sh [--no-video] [--pose flat|tabletop|book|closed]
set -uo pipefail

DEVICE="${DEVICE:-Burrow Demo Duo}"
BUNDLE_ID="com.benx.burrow.duo"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Build/Products/Debug-iphonesimulator/Burrow.app"
VIDEO=1
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-video) VIDEO=0 ;;
    --pose) EXTRA+=(-pose "$2"); shift ;;
  esac
  shift
done

UDID=$(xcrun simctl list devices available | grep -E "^\s+$DEVICE \(" | grep -oE '[0-9A-F-]{36}' | head -1)
if [[ -z "$UDID" ]]; then echo "No simulator named '$DEVICE'"; exit 1; fi
echo "Using $DEVICE ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" >/dev/null
open -a Simulator --args -CurrentDeviceUDID "$UDID" 2>/dev/null || true

# Clean status bar. Apply each flag separately so one the Duo rejects doesn't block the rest.
for flags in "--time 9:41" "--batteryState charged --batteryLevel 100" "--cellularMode active --cellularBars 4" \
             "--wifiMode active --wifiBars 3" "--dataNetwork wifi" "--operatorName ''"; do
  eval xcrun simctl status_bar "$UDID" override $flags 2>/dev/null || echo "  (skipped: $flags)"
done

if [[ -d "$APP" ]]; then xcrun simctl install "$UDID" "$APP"; fi
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" -recording "${EXTRA[@]}"

if [[ $VIDEO -eq 0 ]]; then
  echo "Launched in recording mode. Start your Device Hub screen recording now."
  exit 0
fi

mkdir -p "$ROOT/recordings"
OUT="$ROOT/recordings/burrow-$(date +%Y%m%d-%H%M%S).mp4"
echo "Recording to $OUT. Press Ctrl+C to stop."
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT" &
REC=$!
trap 'kill -INT $REC 2>/dev/null; wait $REC 2>/dev/null; echo "Saved $OUT"; exit 0' INT TERM
wait $REC
