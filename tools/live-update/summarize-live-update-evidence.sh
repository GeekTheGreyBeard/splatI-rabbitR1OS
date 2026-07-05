#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: summarize-live-update-evidence.sh EVIDENCE_DIR

Summarize a Rabbit/OpenClaw live-update evidence directory and write summary.md.
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 2
fi

EVIDENCE_DIR="${1%/}"
if [ ! -d "$EVIDENCE_DIR" ]; then
  echo "evidence directory not found: $EVIDENCE_DIR" >&2
  exit 1
fi

SUMMARY="$EVIDENCE_DIR/summary.md"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FAIL_COUNT=0
WARN_COUNT=0

has_file() {
  [ -s "$EVIDENCE_DIR/$1" ]
}

first_line() {
  local file="$1"
  if has_file "$file"; then
    sed -n '1p' "$EVIDENCE_DIR/$file"
  else
    echo "missing"
  fi
}

excerpt() {
  local file="$1"
  local lines="${2:-8}"
  if has_file "$file"; then
    sed -n "1,${lines}p" "$EVIDENCE_DIR/$file"
  else
    echo "missing: $file"
  fi
}

status_required() {
  local file="$1"
  local label="$2"
  if has_file "$file"; then
    echo "- PASS: $label ($file)"
  else
    echo "- FAIL: $label ($file missing or empty)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

status_optional() {
  local file="$1"
  local label="$2"
  if has_file "$file"; then
    echo "- PASS: $label ($file)"
  else
    echo "- WARN: $label ($file missing or empty)"
    WARN_COUNT=$((WARN_COUNT + 1))
  fi
}

package_hash() {
  if has_file "package.tar.gz.sha256"; then
    awk '{print $1}' "$EVIDENCE_DIR/package.tar.gz.sha256"
  else
    echo "missing"
  fi
}

completion_state() {
  if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "fail"
  elif [ "$WARN_COUNT" -gt 0 ]; then
    echo "warn"
  else
    echo "pass"
  fi
}

{
  echo "# Rabbit/OpenClaw Live Update Evidence Summary"
  echo
  echo "- Summary generated UTC: $STAMP"
  echo "- Evidence directory: $EVIDENCE_DIR"
  echo "- Package SHA256: $(package_hash)"
  echo "- Production touched: no evidence of production deployment in this summary helper"
  echo
  echo "## Device Identity"
  echo
  echo "- Model before: $(first_line device-identity-before.txt)"
  echo "- Build fingerprint before: $(first_line build-fingerprint-before.txt)"
  echo "- ADB devices before: $(first_line adb-devices-before.txt)"
  if has_file "openclaw-package-after.txt"; then
    echo "- OpenClaw package after: captured"
  else
    echo "- OpenClaw package after: missing"
  fi
  echo
  echo "## Required Evidence"
  echo
  status_required "package.tar.gz.sha256" "host package checksum"
  status_required "remote-sha256.txt" "device package checksum validation"
  status_required "adb-devices-before.txt" "ADB device list before update"
  status_required "device-identity-before.txt" "device model before update"
  status_required "build-fingerprint-before.txt" "build fingerprint before update"
  status_optional "openclaw-install.txt" "OpenClaw APK install result, when package includes APK"
  status_required "openclaw-start.txt" "OpenClaw activity start"
  status_required "openclaw-service-start.txt" "OpenClaw foreground service start"
  status_required "boot-warm-run.txt" "boot warm execution"
  status_required "openclaw-package-after.txt" "OpenClaw package state after update"
  status_required "df-before.txt" "filesystem state before update"
  status_required "df-after.txt" "filesystem state after update"
  status_required "live-update-logs.txt" "live-update runtime logs"
  if has_file "adb-remount.txt"; then
    status_required "adb-remount.txt" "system remount attempt"
    status_optional "system-side-button.txt" "system side-button write"
    status_optional "system-boot-warm.txt" "system boot-warm write"
    status_optional "system-live-update.txt" "system live-update write"
    status_optional "system-init.txt" "system init write"
    status_optional "system-manifest.txt" "system manifest write"
  else
    echo "- PASS: system write not requested or remount evidence absent"
  fi
  echo
  echo "## Key Excerpts"
  echo
  echo "### Remote SHA256"
  echo
  echo '```text'
  excerpt "remote-sha256.txt" 12
  echo '```'
  echo
  echo "### OpenClaw Start"
  echo
  echo '```text'
  excerpt "openclaw-start.txt" 8
  echo '```'
  echo
  echo "### OpenClaw Service"
  echo
  echo '```text'
  excerpt "openclaw-service-start.txt" 8
  echo '```'
  echo
  echo "### Boot Warm"
  echo
  echo '```text'
  excerpt "boot-warm-run.txt" 20
  echo '```'
  echo
  echo "## Rollback Notes"
  echo
  if has_file "adb-remount.txt"; then
    echo "- System-write evidence is present. If writes succeeded, restore changed /system files from captured backup or the last validated image, reapply modes, sync, reboot, and recapture service evidence."
    echo "- If remount failed before writes, record the failure and no system rollback is required."
  else
    echo "- Runtime staging rollback applies: reinstall the previous OpenClaw APK if needed, stop temporary side-button watcher, remove temporary /data/local/tmp live-update files, and recapture package/service evidence."
  fi
  echo
  echo "## Completion"
  echo
  echo "- Required failures: $FAIL_COUNT"
  echo "- Warnings: $WARN_COUNT"
  echo "- Completion state: $(completion_state)"
} > "$SUMMARY"

echo "$SUMMARY"
test "$FAIL_COUNT" -eq 0
