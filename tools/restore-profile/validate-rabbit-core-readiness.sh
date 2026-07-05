#!/usr/bin/env bash
set -euo pipefail

ADB="${ADB:-/run/media/gtgb/GTGB-Files/Developer/android-sdk/platform-tools/adb}"
SERIAL="${ANDROID_SERIAL:-}"
OUT_ROOT="${RABOBSTER_CORE_READINESS_OUT:-/run/media/gtgb/GTGB-Files/OpenClaw/artifacts/rabbit/coreReadiness}"

usage() {
  cat <<'USAGE'
Usage: validate-rabbit-core-readiness.sh [options]

Validate post-flash Rabbit/OpenClaw core device readiness.

Options:
  --serial SERIAL    ADB serial. Defaults to ANDROID_SERIAL or the single device.
  --out-root PATH    Artifact root. Defaults to GTGB-Files OpenClaw artifacts.
  -h, --help         Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --serial)
      SERIAL="${2:?missing value for --serial}"
      shift 2
      ;;
    --out-root)
      OUT_ROOT="${2:?missing value for --out-root}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ ! -x "$ADB" ]; then
  echo "ADB not executable: $ADB" >&2
  exit 1
fi

if [ -z "$SERIAL" ]; then
  mapfile -t DEVICES < <("$ADB" devices | awk 'NR > 1 && $2 == "device" {print $1}')
  if [ "${#DEVICES[@]}" -ne 1 ]; then
    echo "set --serial or ANDROID_SERIAL; connected device count: ${#DEVICES[@]}" >&2
    exit 1
  fi
  SERIAL="${DEVICES[0]}"
fi

adb_cmd() {
  "$ADB" -s "$SERIAL" "$@"
}

record() {
  local path="$1"
  shift
  {
    echo "$ $*"
    "$@" 2>&1 || true
  } > "$path"
}

check_package() {
  local pkg="$1"
  local label="$2"
  if adb_cmd shell pm path "$pkg" >/dev/null 2>&1; then
    echo "PASS: $label installed ($pkg)" | tee -a "$SUMMARY" >/dev/null
  else
    echo "FAIL: $label missing ($pkg)" | tee -a "$SUMMARY" >/dev/null
    FAILURES=$((FAILURES + 1))
  fi
}

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$OUT_ROOT/$STAMP-$SERIAL"
mkdir -p "$OUT_DIR"/{screens,settings,packages}
SUMMARY="$OUT_DIR/READINESS_SUMMARY.md"
FAILURES=0

cat > "$SUMMARY" <<EOF
# Rabbit/OpenClaw Core Readiness Summary

- Captured at UTC: $STAMP
- Serial: $SERIAL

## Automated Checks

EOF

record "$OUT_DIR/adb-devices.txt" "$ADB" devices -l
record "$OUT_DIR/device-identity.txt" adb_cmd shell getprop ro.product.model
record "$OUT_DIR/build-fingerprint.txt" adb_cmd shell getprop ro.build.fingerprint
record "$OUT_DIR/packages/packages-third-party.txt" adb_cmd shell pm list packages -3 -f
record "$OUT_DIR/settings/global.txt" adb_cmd shell settings list global
record "$OUT_DIR/settings/secure.txt" adb_cmd shell settings list secure
record "$OUT_DIR/settings/system.txt" adb_cmd shell settings list system
record "$OUT_DIR/default-browser.txt" adb_cmd shell cmd package resolve-activity --brief -a android.intent.action.VIEW -d https://example.com
record "$OUT_DIR/browser-role-holder.txt" adb_cmd shell cmd role get-role-holders android.app.role.BROWSER
record "$OUT_DIR/wallpaper-state.txt" adb_cmd shell dumpsys wallpaper
record "$OUT_DIR/window-state.txt" adb_cmd shell dumpsys window

check_package "com.tailscale.ipn" "Tailscale"
check_package "ai.openclaw.app" "OpenClaw"
if adb_cmd shell pm path com.friend.ios >/dev/null 2>&1 || adb_cmd shell pm path com.friend.ios.dev >/dev/null 2>&1; then
  echo "PASS: Omi installed (com.friend.ios or com.friend.ios.dev)" >> "$SUMMARY"
else
  echo "FAIL: Omi missing (com.friend.ios or com.friend.ios.dev)" >> "$SUMMARY"
  FAILURES=$((FAILURES + 1))
fi
check_package "com.spotify.music" "Spotify"
check_package "org.mozilla.fennec_fdroid" "Fennec"

if grep -q 'org.mozilla.fennec_fdroid' "$OUT_DIR/default-browser.txt"; then
  echo "PASS: Fennec resolves default browser intent" >> "$SUMMARY"
else
  echo "FAIL: Fennec is not the default browser handler" >> "$SUMMARY"
  FAILURES=$((FAILURES + 1))
fi

record "$OUT_DIR/openclaw-start.txt" adb_cmd shell am start -n ai.openclaw.app/.MainActivity --activity-single-top --activity-clear-top
record "$OUT_DIR/openclaw-service-start.txt" adb_cmd shell am start-foreground-service ai.openclaw.app/.NodeForegroundService
record "$OUT_DIR/tailscale-state.txt" adb_cmd shell dumpsys package com.tailscale.ipn
record "$OUT_DIR/spotify-state.txt" adb_cmd shell dumpsys package com.spotify.music

adb_cmd shell uiautomator dump /sdcard/rabbit-core-readiness-home.xml >/dev/null 2>&1 || true
adb_cmd pull /sdcard/rabbit-core-readiness-home.xml "$OUT_DIR/screens/home.xml" >/dev/null 2>&1 || true
adb_cmd exec-out screencap -p > "$OUT_DIR/screens/home.png" 2>/dev/null || true

cat >> "$SUMMARY" <<EOF

## Interactive Auth Required

- Tailscale: user must complete login/VPN approval from projected device screen.
- OpenClaw: user/operator must complete normal pairing/setup approval.
- Spotify: user must complete login from projected device screen.

## Evidence Files

- Default browser evidence: default-browser.txt
- Wallpaper evidence: wallpaper-state.txt
- Launcher/window evidence: window-state.txt and screens/
- OpenClaw evidence: openclaw-start.txt, openclaw-service-start.txt
- Tailscale evidence: tailscale-state.txt
- Spotify evidence: spotify-state.txt

## Result

- Automated failure count: $FAILURES
EOF

if [ "$FAILURES" -eq 0 ]; then
  echo "- Automated readiness state: pass, pending interactive auth" >> "$SUMMARY"
else
  echo "- Automated readiness state: fail" >> "$SUMMARY"
fi

echo "$OUT_DIR"
exit "$FAILURES"
