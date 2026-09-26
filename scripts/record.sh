#!/bin/bash
# Usage: scripts/record.sh [path/to/RABBITHELPER.app]
# Optional: SIMULATOR_UDID, RECORDINGS_DIR, DISPLAY_ID (3 inner, 1 outer), POSE.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && /bin/pwd)"
BUNDLE_ID="app.bitrig.new.2e29e0cf-4508-4e6e-8523-8414f3a4c73d"
RECORDINGS_DIR="${RECORDINGS_DIR:-$PROJECT_ROOT/recordings}"
mkdir -p "$RECORDINGS_DIR"

if [[ -z "${SIMULATOR_UDID:-}" ]]; then
  SIMULATOR_UDID="$(xcrun simctl list devices available --json | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
devices=[v for k,vs in d.items() if k.endswith("iOS-27-1") for v in vs
         if v.get("deviceTypeIdentifier","").endswith("iPhone-Duo")]
devices.sort(key=lambda v:(v["state"]!="Booted",v["name"]!="Burrow Duo"))
if devices: print(devices[0]["udid"])
')"
fi
if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(xcrun simctl create 'Burrow Duo' com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1)"
fi
echo "Recording simulator: $SIMULATOR_UDID"
# Use the selected UUID instead of ambiguous 'booted' when another project
# also has a running simulator.
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

APP_PATH="${1:-}"
if [[ -z "$APP_PATH" ]]; then
  APP_PATH="$(python3 - "$PROJECT_ROOT" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1])
build=p.parent.parent/"Builds"/p.name/"BuildProducts"
apps=list(build.glob("builtin-simulator/**/Debug-iphonesimulator/RABBITHELPER.app"))
if apps: print(max(apps,key=lambda a:a.stat().st_mtime))
PY
)"
fi
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Build RABBITHELPER in Bitrig first, or pass its .app path." >&2
  exit 1
fi
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"

override() {
  if ! xcrun simctl status_bar "$SIMULATOR_UDID" override "$@"; then
    echo "Simulator rejected status-bar option; skipping: $*" >&2
  fi
}
override --time '9:41'
override --batteryState charged
override --batteryLevel 100
override --wifiMode active
override --wifiBars 3
override --cellularMode active
override --cellularBars 4

xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
LAUNCH_ARGS=(-recording)
if [[ -n "${POSE:-}" ]]; then
  case "$POSE" in flat|tabletop|book|closed) LAUNCH_ARGS+=(-pose "$POSE");;
    *) echo "Invalid POSE: $POSE" >&2; exit 1;; esac
fi
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" "${LAUNCH_ARGS[@]}"

STAMP="$(date +%Y%m%d-%H%M%S)"
# This runtime permits one host recorder at a time. Capture the inner take,
# then use DISPLAY_ID=1 for a separate outer-display closing shot.
DISPLAY_ID="${DISPLAY_ID:-3}"
case "$DISPLAY_ID" in 3) PANEL=inner;; 1) PANEL=outer;;
  *) echo "DISPLAY_ID must be 3 (inner) or 1 (outer)." >&2; exit 1;; esac
MOVIE="$RECORDINGS_DIR/rabbithelper-$STAMP-$PANEL.mp4"
RECORDER_PID=""
cleanup() {
  trap - INT TERM EXIT
  if [[ -n "$RECORDER_PID" ]]; then
    kill -INT "$RECORDER_PID" 2>/dev/null || true
    wait "$RECORDER_PID" || true
  fi
  xcrun simctl status_bar "$SIMULATOR_UDID" clear || true
  if [[ -s "$MOVIE" ]]; then echo "Saved recording: $MOVIE"
  else echo "No movie was saved. Check the simulator recorder output." >&2; fi
}
trap cleanup INT TERM EXIT
xcrun simctl io "$SIMULATOR_UDID" recordVideo --codec=h264 --display="$DISPLAY_ID" "$MOVIE" &
RECORDER_PID="$!"
echo "Recording the $PANEL display. Press Ctrl+C to finish."
wait "$RECORDER_PID"
