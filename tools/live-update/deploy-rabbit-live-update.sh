#!/usr/bin/env bash
set -euo pipefail

ADB="${ADB:-adb}"
SERIAL="${ANDROID_SERIAL:-}"
PACKAGE=""
APPLY_SYSTEM=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
EVIDENCE_ROOT="${RABOBSTER_LIVE_UPDATE_EVIDENCE:-$ROOT_DIR/artifacts/liveUpdates/evidence}"
REMOTE_ROOT="/data/local/tmp/rabobster-live-update"
FORCE_FINGERPRINT=false
ALLOW_UNSIGNED_PRODUCTION=false
VERIFY_KEY="${RABOBSTER_LIVE_UPDATE_VERIFY_KEY:-}"

usage() {
  cat <<'USAGE'
Usage: deploy-rabbit-live-update.sh --package PATH [options]

Deploy a Rabbit/OpenClaw live-update package without wiping user data.

Options:
  --package PATH     Package produced by build-rabbit-live-update-package.sh.
  --serial SERIAL    ADB serial. Defaults to ANDROID_SERIAL or the single connected device.
  --apply-system     Also attempt adb remount and copy scripts/init into /system.
                     Runtime /data/local/tmp update is always applied first.
  --force-fingerprint
                     Allow a target_fingerprint mismatch for staging operations.
  --allow-unsigned-production
                     Allow unsigned non-staging packages. Requires operator intent.
  --verify-key PATH  OpenSSL public key used to verify SHA256SUMS.sig.
                     Defaults to RABOBSTER_LIVE_UPDATE_VERIFY_KEY.
  --evidence PATH    Evidence directory root. Defaults to repo-local artifacts/liveUpdates/evidence.
  -h, --help         Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --package)
      PACKAGE="${2:?missing value for --package}"
      shift 2
      ;;
    --serial)
      SERIAL="${2:?missing value for --serial}"
      shift 2
      ;;
    --apply-system)
      APPLY_SYSTEM=true
      shift
      ;;
    --force-fingerprint)
      FORCE_FINGERPRINT=true
      shift
      ;;
    --allow-unsigned-production)
      ALLOW_UNSIGNED_PRODUCTION=true
      shift
      ;;
    --verify-key)
      VERIFY_KEY="${2:?missing value for --verify-key}"
      shift 2
      ;;
    --evidence)
      EVIDENCE_ROOT="${2:?missing value for --evidence}"
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

if [ -z "$PACKAGE" ] || [ ! -f "$PACKAGE" ]; then
  echo "--package must point to an existing tarball" >&2
  exit 1
fi

manifest_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key {print $2; found=1; exit} END {if (!found) exit 1}'
}

PACKAGE_MANIFEST="$(tar -xOf "$PACKAGE" manifest.properties)"
PACKAGE_CHANNEL="$(printf '%s\n' "$PACKAGE_MANIFEST" | manifest_value channel || true)"
PACKAGE_PAYLOAD_TYPE="$(printf '%s\n' "$PACKAGE_MANIFEST" | manifest_value payload_type || true)"
PACKAGE_TARGET_DEVICE="$(printf '%s\n' "$PACKAGE_MANIFEST" | manifest_value target_device || true)"
PACKAGE_SIGNATURE_REQUIRED="$(printf '%s\n' "$PACKAGE_MANIFEST" | manifest_value signature_required || true)"
PACKAGE_TARGET_FINGERPRINT="$(printf '%s\n' "$PACKAGE_MANIFEST" | manifest_value target_fingerprint || true)"

if [ "$PACKAGE_TARGET_DEVICE" != "rabbit_r1" ]; then
  echo "package target_device must be rabbit_r1; got: ${PACKAGE_TARGET_DEVICE:-missing}" >&2
  exit 1
fi

case "$PACKAGE_PAYLOAD_TYPE" in
  runtime|system|ota|ab_ota) ;;
  *)
    echo "package payload_type must be one of runtime, system, ota, ab_ota; got: ${PACKAGE_PAYLOAD_TYPE:-missing}" >&2
    exit 1
    ;;
esac

if [ "$PACKAGE_CHANNEL" != "staging" ] && [ "$PACKAGE_SIGNATURE_REQUIRED" != "false" ]; then
  SIGNATURE_TMP="$(mktemp -d)"
  trap 'rm -rf "$SIGNATURE_TMP"' EXIT
  if ! tar -xOf "$PACKAGE" SHA256SUMS > "$SIGNATURE_TMP/SHA256SUMS" 2>/dev/null; then
    echo "refusing non-staging package without SHA256SUMS" >&2
    exit 1
  fi
  if ! tar -xOf "$PACKAGE" SHA256SUMS.sig > "$SIGNATURE_TMP/SHA256SUMS.sig" 2>/dev/null; then
    if [ "$ALLOW_UNSIGNED_PRODUCTION" != true ]; then
      echo "refusing unsigned non-staging package; include SHA256SUMS.sig or use --allow-unsigned-production for an explicit emergency override" >&2
      exit 1
    fi
  elif [ -z "$VERIFY_KEY" ] || [ ! -f "$VERIFY_KEY" ]; then
    if [ "$ALLOW_UNSIGNED_PRODUCTION" != true ]; then
      echo "refusing signed non-staging package without a valid --verify-key or RABOBSTER_LIVE_UPDATE_VERIFY_KEY" >&2
      exit 1
    fi
  elif ! openssl dgst -sha256 -verify "$VERIFY_KEY" -signature "$SIGNATURE_TMP/SHA256SUMS.sig" "$SIGNATURE_TMP/SHA256SUMS" >/dev/null; then
    echo "refusing non-staging package: SHA256SUMS.sig verification failed" >&2
    exit 1
  fi
fi

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

shell_cmd() {
  adb_cmd shell "$@"
}

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$EVIDENCE_ROOT/$STAMP-$SERIAL"
mkdir -p "$EVIDENCE_DIR"

record() {
  local name="$1"
  shift
  {
    echo "$ $*"
    "$@" 2>&1 || true
  } | tee "$EVIDENCE_DIR/$name.txt" >/dev/null
}

record "adb-devices-before" "$ADB" devices -l
record "device-identity-before" adb_cmd shell getprop ro.product.model
record "build-fingerprint-before" adb_cmd shell getprop ro.build.fingerprint
record "selinux-before" adb_cmd shell getenforce
record "df-before" adb_cmd shell df -h /
record "mount-before" adb_cmd shell mount
record "openclaw-package-before" adb_cmd shell dumpsys package ai.openclaw.app
record "tailscale-package-before" adb_cmd shell dumpsys package com.tailscale.ipn

DEVICE_FINGERPRINT="$(adb_cmd shell getprop ro.build.fingerprint | tr -d '\r')"
if [ -n "$PACKAGE_TARGET_FINGERPRINT" ] && [ "$PACKAGE_TARGET_FINGERPRINT" != "any" ] && [ "$PACKAGE_TARGET_FINGERPRINT" != "$DEVICE_FINGERPRINT" ]; then
  if [ "$FORCE_FINGERPRINT" != true ]; then
    echo "target_fingerprint mismatch: package=$PACKAGE_TARGET_FINGERPRINT device=$DEVICE_FINGERPRINT" | tee "$EVIDENCE_DIR/fingerprint-gate.txt" >&2
    exit 1
  fi
  echo "forced target_fingerprint mismatch: package=$PACKAGE_TARGET_FINGERPRINT device=$DEVICE_FINGERPRINT" | tee "$EVIDENCE_DIR/fingerprint-gate.txt"
else
  echo "target_fingerprint accepted: package=${PACKAGE_TARGET_FINGERPRINT:-unset} device=$DEVICE_FINGERPRINT" | tee "$EVIDENCE_DIR/fingerprint-gate.txt" >/dev/null
fi

cp "$PACKAGE" "$EVIDENCE_DIR/package.tar.gz"
sha256sum "$PACKAGE" > "$EVIDENCE_DIR/package.tar.gz.sha256"

adb_cmd shell "rm -rf '$REMOTE_ROOT' && mkdir -p '$REMOTE_ROOT'"
adb_cmd push "$PACKAGE" "$REMOTE_ROOT/package.tar.gz" >/dev/null
shell_cmd "cd '$REMOTE_ROOT' && tar -xzf package.tar.gz && sha256sum -c SHA256SUMS" | tee "$EVIDENCE_DIR/remote-sha256.txt"

if shell_cmd "[ -f '$REMOTE_ROOT/payload/apks/openclaw.apk' ]"; then
  shell_cmd "pm install -r -d '$REMOTE_ROOT/payload/apks/openclaw.apk'" | tee "$EVIDENCE_DIR/openclaw-install.txt"
fi

if shell_cmd "[ -f '$REMOTE_ROOT/payload/apks/tailscale.apk' ]"; then
  shell_cmd "pm install -r -d '$REMOTE_ROOT/payload/apks/tailscale.apk'" | tee "$EVIDENCE_DIR/tailscale-install.txt"
fi

shell_cmd "cp '$REMOTE_ROOT/payload/system/bin/rabobster-side-button' /data/local/tmp/rabobster-side-button && chmod 0755 /data/local/tmp/rabobster-side-button"
shell_cmd "cp '$REMOTE_ROOT/payload/system/bin/rabobster-boot-warm' /data/local/tmp/rabobster-boot-warm && chmod 0755 /data/local/tmp/rabobster-boot-warm"
shell_cmd "cp '$REMOTE_ROOT/payload/system/bin/rabobster-live-update' /data/local/tmp/rabobster-live-update && chmod 0755 /data/local/tmp/rabobster-live-update"
shell_cmd "if [ -f /data/local/tmp/rabobster-side-button.pid ]; then old_pid=\$(cat /data/local/tmp/rabobster-side-button.pid 2>/dev/null || true); [ -n \"\$old_pid\" ] && kill \"\$old_pid\" >/dev/null 2>&1 || true; fi"
shell_cmd "rm -f /data/local/tmp/rabobster-side-button.pid /data/local/tmp/rabobster-side-button.lasttap"
nohup "$ADB" -s "$SERIAL" shell "cd /data/local/tmp && ./rabobster-side-button" > "$EVIDENCE_DIR/host-side-button-adb.log" 2>&1 &
echo "$!" > "$EVIDENCE_DIR/host-side-button-adb.pid"
sleep 1
record "side-button-runtime-status" adb_cmd shell "pid=\$(cat /data/local/tmp/rabobster-side-button.pid 2>/dev/null || true); if [ -n \"\$pid\" ] && [ -d \"/proc/\$pid\" ]; then echo running:\$pid; else echo not-running; fi"
shell_cmd "/data/local/tmp/rabobster-boot-warm >/dev/null 2>&1; tail -n 40 /data/local/tmp/rabobster-boot-warm.log" | tee "$EVIDENCE_DIR/boot-warm-run.txt"

if [ "$APPLY_SYSTEM" = true ]; then
  record "adb-remount" adb_cmd remount
  shell_cmd "cp '$REMOTE_ROOT/payload/system/bin/rabobster-side-button' /system/bin/rabobster-side-button && chmod 0755 /system/bin/rabobster-side-button" | tee "$EVIDENCE_DIR/system-side-button.txt"
  shell_cmd "cp '$REMOTE_ROOT/payload/system/bin/rabobster-boot-warm' /system/bin/rabobster-boot-warm && chmod 0755 /system/bin/rabobster-boot-warm" | tee "$EVIDENCE_DIR/system-boot-warm.txt"
  shell_cmd "cp '$REMOTE_ROOT/payload/system/bin/rabobster-live-update' /system/bin/rabobster-live-update && chmod 0755 /system/bin/rabobster-live-update" | tee "$EVIDENCE_DIR/system-live-update.txt"
  shell_cmd "cp '$REMOTE_ROOT/payload/system/etc/init/r1_side_button.rc' /system/etc/init/r1_side_button.rc && chmod 0644 /system/etc/init/r1_side_button.rc" | tee "$EVIDENCE_DIR/system-init.txt"
  shell_cmd "mkdir -p /system/etc/rabobster-live-update && cp '$REMOTE_ROOT/payload/system/etc/rabobster-live-update/manifest.properties' /system/etc/rabobster-live-update/manifest.properties && chmod 0644 /system/etc/rabobster-live-update/manifest.properties" | tee "$EVIDENCE_DIR/system-manifest.txt"
  shell_cmd "sync"
fi

shell_cmd "am start -n ai.openclaw.app/.MainActivity --activity-single-top --activity-clear-top" | tee "$EVIDENCE_DIR/openclaw-start.txt"
shell_cmd "am start-foreground-service ai.openclaw.app/.NodeForegroundService" | tee "$EVIDENCE_DIR/openclaw-service-start.txt"

record "openclaw-package-after" adb_cmd shell dumpsys package ai.openclaw.app
record "tailscale-package-after" adb_cmd shell dumpsys package com.tailscale.ipn
record "df-after" adb_cmd shell df -h /
record "live-update-logs" adb_cmd shell "tail -n 200 /data/local/tmp/rabobster-boot-warm.log /data/local/tmp/rabobster-side-button-events.log"

echo "$EVIDENCE_DIR"
