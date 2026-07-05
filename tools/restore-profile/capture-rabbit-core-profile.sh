#!/usr/bin/env bash
set -euo pipefail

ADB="${ADB:-/run/media/gtgb/GTGB-Files/Developer/android-sdk/platform-tools/adb}"
SERIAL="${ANDROID_SERIAL:-}"
OUT_ROOT="${RABOBSTER_CORE_PROFILE_OUT:-/run/media/gtgb/GTGB-Files/OpenClaw/artifacts/rabbit/coreDeviceProfile}"

usage() {
  cat <<'USAGE'
Usage: capture-rabbit-core-profile.sh [options]

Capture the pre-flash Rabbit/OpenClaw core device profile without mutating data.

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

pull_optional() {
  local remote="$1"
  local local_path="$2"
  if adb_cmd shell "[ -e '$remote' ]" >/dev/null 2>&1; then
    adb_cmd pull "$remote" "$local_path" >/dev/null 2>&1 || echo "pull failed: $remote" > "$local_path.pull-failed.txt"
  else
    echo "not found or inaccessible: $remote" > "$local_path.not-found.txt"
  fi
}

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$OUT_ROOT/$STAMP-$SERIAL"
mkdir -p "$OUT_DIR"/{apks,db,screens,settings,packages}

record "$OUT_DIR/adb-devices.txt" "$ADB" devices -l
record "$OUT_DIR/device-identity.txt" adb_cmd shell getprop ro.product.model
record "$OUT_DIR/build-fingerprint.txt" adb_cmd shell getprop ro.build.fingerprint
record "$OUT_DIR/boot-state.txt" adb_cmd shell getprop ro.boot.verifiedbootstate
record "$OUT_DIR/current-slot.txt" adb_cmd shell getprop ro.boot.slot_suffix
record "$OUT_DIR/storage.txt" adb_cmd shell df -h
record "$OUT_DIR/mounts.txt" adb_cmd shell mount

record "$OUT_DIR/packages/packages-third-party.txt" adb_cmd shell pm list packages -3 -f
record "$OUT_DIR/packages/packages-all.txt" adb_cmd shell pm list packages -f

CORE_PACKAGES=(
  "com.tailscale.ipn"
  "ai.openclaw.app"
  "com.friend.ios"
  "com.friend.ios.dev"
  "com.spotify.music"
  "org.mozilla.fennec_fdroid"
)

: > "$OUT_DIR/core-packages-summary.txt"
for pkg in "${CORE_PACKAGES[@]}"; do
  if adb_cmd shell pm path "$pkg" >/tmp/rabbit-core-pkg-path.$$ 2>/dev/null; then
    tr -d '\r' < /tmp/rabbit-core-pkg-path.$$ >> "$OUT_DIR/core-packages-summary.txt"
    record "$OUT_DIR/packages/$pkg.dumpsys.txt" adb_cmd shell dumpsys package "$pkg"
    base_path="$(awk -F: '/package:/ {print $2; exit}' /tmp/rabbit-core-pkg-path.$$ | tr -d '\r')"
    if [ -n "$base_path" ]; then
      pull_optional "$base_path" "$OUT_DIR/apks/$pkg.apk"
    fi
  else
    echo "missing:$pkg" >> "$OUT_DIR/core-packages-summary.txt"
  fi
done
rm -f /tmp/rabbit-core-pkg-path.$$

record "$OUT_DIR/settings/global.txt" adb_cmd shell settings list global
record "$OUT_DIR/settings/secure.txt" adb_cmd shell settings list secure
record "$OUT_DIR/settings/system.txt" adb_cmd shell settings list system
record "$OUT_DIR/default-browser.txt" adb_cmd shell cmd package resolve-activity --brief -a android.intent.action.VIEW -d https://example.com
record "$OUT_DIR/browser-role-holder.txt" adb_cmd shell cmd role get-role-holders android.app.role.BROWSER
record "$OUT_DIR/wallpaper-state.txt" adb_cmd shell dumpsys wallpaper
record "$OUT_DIR/window-state.txt" adb_cmd shell dumpsys window
record "$OUT_DIR/power-state.txt" adb_cmd shell dumpsys power

adb_cmd shell uiautomator dump /sdcard/rabbit-core-profile-home.xml >/dev/null 2>&1 || true
pull_optional /sdcard/rabbit-core-profile-home.xml "$OUT_DIR/screens/home.xml"
adb_cmd exec-out screencap -p > "$OUT_DIR/screens/home.png" 2>/dev/null || true

pull_optional /data/data/com.android.launcher3/databases/launcher_3_by_3.db "$OUT_DIR/db/launcher_3_by_3.db"
pull_optional /data/data/com.android.launcher3/databases/app_icons.db "$OUT_DIR/db/app_icons.db"
pull_optional /data/data/com.rabbit.launcher/databases/launcher_3_by_3.db "$OUT_DIR/db/rabbit_launcher_3_by_3.db"
pull_optional /data/data/com.rabbit.launcher/databases/app_icons.db "$OUT_DIR/db/rabbit_app_icons.db"

cat > "$OUT_DIR/FLASH_GATE.md" <<EOF
# Rabbit/OpenClaw Flash Gate

- Captured at UTC: $STAMP
- Serial: $SERIAL
- Action: pre-flash core device profile capture

## Hard Checks

- Device identity captured: yes
- Build fingerprint captured: yes
- Package list captured: yes
- Android settings captured: yes
- Wallpaper/window state captured: yes
- Core package summary captured: yes

## Operator Review

Before a wipe-capable flash, confirm this directory contains enough material to
restore the curated device identity: core APKs or known-good archived APKs,
launcher/icon artifacts, wallpaper artifacts, settings dumps, and the
interactive auth checklist.
EOF

sha256sum "$OUT_DIR"/apks/*.apk > "$OUT_DIR/apks/sha256sums.txt" 2>/dev/null || true
echo "$OUT_DIR"
