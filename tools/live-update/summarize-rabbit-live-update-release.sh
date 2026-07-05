#!/usr/bin/env bash
set -euo pipefail

PACKAGE=""
EVIDENCE_DIR=""
OUT_FILE=""

usage() {
  cat <<'USAGE'
Usage: summarize-rabbit-live-update-release.sh --package PATH --evidence DIR [options]

Create a concise Markdown release/evidence summary for a Rabbit/OpenClaw
live-update package.

Options:
  --package PATH   Live-update package tarball.
  --evidence DIR   Evidence directory from deploy-rabbit-live-update.sh.
  --out PATH       Output Markdown file. Defaults to <evidence>/RELEASE_SUMMARY.md.
  -h, --help       Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --package)
      PACKAGE="${2:?missing value for --package}"
      shift 2
      ;;
    --evidence)
      EVIDENCE_DIR="${2:?missing value for --evidence}"
      shift 2
      ;;
    --out)
      OUT_FILE="${2:?missing value for --out}"
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

if [ -z "$EVIDENCE_DIR" ] || [ ! -d "$EVIDENCE_DIR" ]; then
  echo "--evidence must point to an existing evidence directory" >&2
  exit 1
fi

if [ -z "$OUT_FILE" ]; then
  OUT_FILE="$EVIDENCE_DIR/RELEASE_SUMMARY.md"
fi

read_first_match() {
  local file="$1"
  local pattern="$2"
  if [ -f "$file" ]; then
    grep -m 1 -E "$pattern" "$file" || true
  fi
}

status_for() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  if read_first_match "$file" "$pattern" >/dev/null; then
    echo "- $label: pass"
  elif [ -f "$file" ]; then
    echo "- $label: review required"
  else
    echo "- $label: missing"
  fi
}

PACKAGE_SHA="$(sha256sum "$PACKAGE" | awk '{print $1}')"
MANIFEST="$(tar -xOzf "$PACKAGE" manifest.properties 2>/dev/null || true)"
VERSION="$(printf '%s\n' "$MANIFEST" | awk -F= '$1 == "version" {print $2; exit}')"
CHANNEL="$(printf '%s\n' "$MANIFEST" | awk -F= '$1 == "channel" {print $2; exit}')"
PAYLOAD_TYPE="$(printf '%s\n' "$MANIFEST" | awk -F= '$1 == "payload_type" {print $2; exit}')"
SIGNATURE_STATE="$(printf '%s\n' "$MANIFEST" | awk -F= '$1 == "signature_state" {print $2; exit}')"
DEVICE_MODEL="$(read_first_match "$EVIDENCE_DIR/device-identity-before.txt" '^[^$].*' | tail -n 1)"
BUILD_FINGERPRINT="$(read_first_match "$EVIDENCE_DIR/build-fingerprint-before.txt" '^[^$].*' | tail -n 1)"

cat > "$OUT_FILE" <<EOF
# Rabbit/OpenClaw Live Update Release Summary

- Package: $PACKAGE
- Package SHA-256: $PACKAGE_SHA
- Version: ${VERSION:-unknown}
- Channel: ${CHANNEL:-unknown}
- Payload type: ${PAYLOAD_TYPE:-unknown}
- Signature state: ${SIGNATURE_STATE:-unknown}
- Evidence directory: $EVIDENCE_DIR
- Device model: ${DEVICE_MODEL:-unknown}
- Build fingerprint: ${BUILD_FINGERPRINT:-unknown}

## Acceptance Evidence

$(status_for "Package checksum verified on device" "$EVIDENCE_DIR/remote-sha256.txt" 'OK$')
$(status_for "OpenClaw APK install" "$EVIDENCE_DIR/openclaw-install.txt" 'Success')
$(status_for "OpenClaw activity start" "$EVIDENCE_DIR/openclaw-start.txt" 'Starting|Warning: Activity not started|Status: ok')
$(status_for "OpenClaw foreground service start" "$EVIDENCE_DIR/openclaw-service-start.txt" 'Starting service|Status: ok')
$(status_for "Boot warm run" "$EVIDENCE_DIR/boot-warm-run.txt" 'boot warm|openclaw|tailscale')
$(status_for "Side-button runtime watcher" "$EVIDENCE_DIR/side-button-runtime-status.txt" '^running:')

## Production Decision

- Runtime updater is acceptable for data-preserving staging and emergency production use.
- Production long-term packages must be signed with SHA256SUMS.sig.
- Durable /system persistence should move through OTA/image validation or an unlocked dev unit, not by unlocking a data-bearing live unit.

## Rollback

- Reinstall previous APK with pm install -r -d when downgrades are allowed.
- Remove /data/local/tmp/rabobster-* runtime scripts if reverting the runtime bridge.
- For OTA/A-B payloads, use the image-specific slot rollback plan before production promotion.
EOF

echo "$OUT_FILE"
