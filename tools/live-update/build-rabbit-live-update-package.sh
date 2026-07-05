#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${RABOBSTER_LIVE_UPDATE_OUT:-$ROOT_DIR/artifacts/liveUpdates}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK_DIR="$(mktemp -d)"

OPENCLAW_APK=""
TAILSCALE_APK=""
VERSION="${RABOBSTER_LIVE_UPDATE_VERSION:-$STAMP}"
CHANNEL="${RABOBSTER_LIVE_UPDATE_CHANNEL:-staging}"
PAYLOAD_TYPE="${RABOBSTER_LIVE_UPDATE_PAYLOAD_TYPE:-runtime}"
PACKAGE_FORMAT_VERSION=1
TARGET_FINGERPRINT="${RABOBSTER_LIVE_UPDATE_TARGET_FINGERPRINT:-any}"
MIN_FINGERPRINT="${RABOBSTER_LIVE_UPDATE_MIN_FINGERPRINT:-any}"
SIGNING_KEY=""

usage() {
  cat <<'USAGE'
Usage: build-rabbit-live-update-package.sh [options]

Build a data-preserving Rabbit/OpenClaw live-update tarball.

Options:
  --openclaw-apk PATH   Include an OpenClaw APK for pm install -r.
  --tailscale-apk PATH  Include a Tailscale APK for pm install -r.
  --version VALUE       Manifest version. Defaults to UTC timestamp.
  --channel VALUE       Package channel. Defaults to staging.
  --payload-type VALUE  One of runtime, system, ota, or ab_ota. Defaults to runtime.
  --target-fingerprint VALUE
                        Exact target build fingerprint. Defaults to any.
  --min-fingerprint VALUE
                        Minimum supported build fingerprint. Defaults to any.
  --signing-key PATH    Optional private key for openssl detached checksum signature.
  --out-dir PATH        Artifact directory. Defaults to repo-local artifacts/liveUpdates.
  -h, --help            Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --openclaw-apk)
      OPENCLAW_APK="${2:?missing value for --openclaw-apk}"
      shift 2
      ;;
    --tailscale-apk)
      TAILSCALE_APK="${2:?missing value for --tailscale-apk}"
      shift 2
      ;;
    --version)
      VERSION="${2:?missing value for --version}"
      shift 2
      ;;
    --channel)
      CHANNEL="${2:?missing value for --channel}"
      shift 2
      ;;
    --payload-type)
      PAYLOAD_TYPE="${2:?missing value for --payload-type}"
      shift 2
      ;;
    --target-fingerprint)
      TARGET_FINGERPRINT="${2:?missing value for --target-fingerprint}"
      shift 2
      ;;
    --min-fingerprint)
      MIN_FINGERPRINT="${2:?missing value for --min-fingerprint}"
      shift 2
      ;;
    --signing-key)
      SIGNING_KEY="${2:?missing value for --signing-key}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:?missing value for --out-dir}"
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

require_file() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "required file missing: $path" >&2
    exit 1
  fi
}

require_optional_file() {
  local path="$1"
  local label="$2"
  if [ -n "$path" ] && [ ! -f "$path" ]; then
    echo "$label not found: $path" >&2
    exit 1
  fi
}

require_file "$ROOT_DIR/device_rabbit_r1/rootdir/system/bin/rabobster-side-button"
require_file "$ROOT_DIR/device_rabbit_r1/rootdir/system/bin/rabobster-boot-warm"
require_file "$ROOT_DIR/device_rabbit_r1/rootdir/system/bin/rabobster-live-update"
require_file "$ROOT_DIR/device_rabbit_r1/rootdir/system/etc/init/r1_side_button.rc"
require_file "$ROOT_DIR/device_rabbit_r1/rootdir/system/etc/rabobster-live-update/manifest.properties"
require_optional_file "$OPENCLAW_APK" "OpenClaw APK"
require_optional_file "$TAILSCALE_APK" "Tailscale APK"
require_optional_file "$SIGNING_KEY" "Signing key"

case "$PAYLOAD_TYPE" in
  runtime|system|ota|ab_ota) ;;
  *)
    echo "--payload-type must be one of: runtime, system, ota, ab_ota" >&2
    exit 2
    ;;
esac

mkdir -p "$OUT_DIR"
mkdir -p "$WORK_DIR/payload/system/bin" "$WORK_DIR/payload/system/etc/init" "$WORK_DIR/payload/system/etc/rabobster-live-update" "$WORK_DIR/payload/apks"

cp "$ROOT_DIR/device_rabbit_r1/rootdir/system/bin/rabobster-side-button" "$WORK_DIR/payload/system/bin/"
cp "$ROOT_DIR/device_rabbit_r1/rootdir/system/bin/rabobster-boot-warm" "$WORK_DIR/payload/system/bin/"
cp "$ROOT_DIR/device_rabbit_r1/rootdir/system/bin/rabobster-live-update" "$WORK_DIR/payload/system/bin/"
cp "$ROOT_DIR/device_rabbit_r1/rootdir/system/etc/init/r1_side_button.rc" "$WORK_DIR/payload/system/etc/init/"
cp "$ROOT_DIR/device_rabbit_r1/rootdir/system/etc/rabobster-live-update/manifest.properties" "$WORK_DIR/payload/system/etc/rabobster-live-update/"

if [ -n "$OPENCLAW_APK" ]; then
  cp "$OPENCLAW_APK" "$WORK_DIR/payload/apks/openclaw.apk"
fi

if [ -n "$TAILSCALE_APK" ]; then
  cp "$TAILSCALE_APK" "$WORK_DIR/payload/apks/tailscale.apk"
fi

cat > "$WORK_DIR/manifest.properties" <<EOF
name=rabbit-openclaw-live-update
version=$VERSION
built_at_utc=$STAMP
package_format_version=$PACKAGE_FORMAT_VERSION
channel=$CHANNEL
payload_type=$PAYLOAD_TYPE
signature_required=$([ "$CHANNEL" = staging ] && echo false || echo true)
signature_scheme=sha256sums-detached
signature_state=$([ -n "$SIGNING_KEY" ] && echo signed || echo unsigned)
target_device=rabbit_r1
target_fingerprint=$TARGET_FINGERPRINT
min_fingerprint=$MIN_FINGERPRINT
openclaw_package=ai.openclaw.app
openclaw_activity=ai.openclaw.app/.MainActivity
openclaw_service=ai.openclaw.app/.NodeForegroundService
tailscale_package=com.tailscale.ipn
tailscale_receiver=com.tailscale.ipn/.IPNReceiver
tailscale_connect_action=com.tailscale.ipn.CONNECT_VPN
contains_openclaw_apk=$([ -n "$OPENCLAW_APK" ] && echo true || echo false)
contains_tailscale_apk=$([ -n "$TAILSCALE_APK" ] && echo true || echo false)
EOF

(
  cd "$WORK_DIR"
  find manifest.properties payload -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

if [ -n "$SIGNING_KEY" ]; then
  openssl dgst -sha256 -sign "$SIGNING_KEY" -out "$WORK_DIR/SHA256SUMS.sig" "$WORK_DIR/SHA256SUMS"
else
  cat > "$WORK_DIR/SHA256SUMS.sig.README" <<'EOF'
This staging package is unsigned. Production packages must include SHA256SUMS.sig
generated with --signing-key and verified before installation.
EOF
fi

cat > "$WORK_DIR/RELEASE_CONTRACT.md" <<EOF
# Rabbit/OpenClaw Live Update Release Contract

- Name: rabbit-openclaw-live-update
- Version: $VERSION
- Channel: $CHANNEL
- Payload type: $PAYLOAD_TYPE
- Target device: rabbit_r1
- Target fingerprint: $TARGET_FINGERPRINT
- Minimum fingerprint: $MIN_FINGERPRINT
- Production signature required: true

## Installer Rules

- Verify package SHA-256 before transfer.
- Verify all entries in SHA256SUMS on device before mutation.
- Reject production packages without SHA256SUMS.sig.
- Reject device or fingerprint mismatches unless a staging operator explicitly forces the install.
- Record before and after evidence for package identity, build fingerprint, APK install, service start, Realtime Talk app readiness, boot warm, and data preservation.

## Rollback Notes

- Runtime payloads mutate /data/local/tmp scripts and package installs only.
- APK rollback requires installing the prior APK with pm install -r -d when downgrade is allowed.
- System, OTA, and A/B OTA payloads must carry slot/image rollback instructions before production use.
EOF

PACKAGE="$OUT_DIR/rabbit-openclaw-live-update-$VERSION.tar.gz"
(
  cd "$WORK_DIR"
  tar -czf "$PACKAGE" manifest.properties SHA256SUMS SHA256SUMS.sig* RELEASE_CONTRACT.md payload
)

sha256sum "$PACKAGE" > "$PACKAGE.sha256"
echo "$PACKAGE"
echo "$PACKAGE.sha256"

rm -rf "$WORK_DIR"
