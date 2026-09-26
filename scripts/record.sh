#!/bin/bash
# Usage: scripts/record.sh [path/to/Burrow.app]
# Optional: SIMULATOR_UDID, RECORDINGS_DIR, POSE (flat/tabletop/book/closed).
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
apps=list(build.glob("builtin-simulator/**/Debug-iphonesimulator/Burrow.app"))
if apps: print(max(apps,key=lambda a:a.stat().st_mtime))
PY
)"
fi
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Build Burrow in Bitrig first, or pass its .app path." >&2
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
# Duo's inner panel is display 3; its outer panel is display 1. The default
# points at the inner panel even when it is off. Capture both for the close.
INNER_DISPLAY="${INNER_DISPLAY:-3}"
OUTER_DISPLAY="${OUTER_DISPLAY:-1}"
PIDS=()
cleanup() {
  trap - INT TERM EXIT
  for pid in "${PIDS[@]}"; do kill -INT "$pid" 2>/dev/null || true; done
  for pid in "${PIDS[@]}"; do wait "$pid" || true; done
  xcrun simctl status_bar "$SIMULATOR_UDID" clear || true
  echo "Saved recordings to $RECORDINGS_DIR/burrow-$STAMP-{inner,outer}.mp4"
}
trap cleanup INT TERM EXIT
xcrun simctl io "$SIMULATOR_UDID" recordVideo --codec=h264 --display="$INNER_DISPLAY" "$RECORDINGS_DIR/burrow-$STAMP-inner.mp4" &
PIDS+=("$!")
xcrun simctl io "$SIMULATOR_UDID" recordVideo --codec=h264 --display="$OUTER_DISPLAY" "$RECORDINGS_DIR/burrow-$STAMP-outer.mp4" &
PIDS+=("$!")
echo "Recording both displays. Use the simulator fold controls; press Ctrl+C to finish."
wait "${PIDS[@]}"
