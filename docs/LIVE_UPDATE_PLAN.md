# Rabbit/OpenClaw Live Update Plan

Goal: stop treating full image flashing as the daily update path. The immediate lane is a data-preserving updater that can refresh OpenClaw, Tailscale, Realtime Talk app readiness, and boot warm behavior on a live Rabbit R1. The ROM lane keeps those same scripts in `device_rabbit_r1` so the next image makes them durable.

## Current 2026-06-21 Status

Usable now:

- `tools/live-update/build-rabbit-live-update-package.sh`
- `tools/live-update/deploy-rabbit-live-update.sh`
- `tools/live-update/SIGNED_PACKAGE_BRIDGE.md`
- package artifact `rabbit-openclaw-live-update-2026.6.21-live-staging-r3.tar.gz`

Verified on Rabbit R1 `919109A4J1600110804E`:

- package checksum validation on device
- OpenClaw APK reinstall with `pm install -r -d`
- OpenClaw activity start
- `ai.openclaw.app/.NodeForegroundService` start
- boot warm script sends Tailscale connect broadcast and starts OpenClaw
- reboot preserves the OpenClaw app install and receiver registration

Blocked for direct system persistence on the current live device:

- `adb remount` returns `Device must be bootloader unlocked`
- copying to `/system/bin` fails with `Read-only file system`
- `/system` is effectively full, with about 11M available

The short-term production-safe label is therefore: data-preserving runtime live update, with durable `/system` persistence reserved for the next image, signed OTA, or an explicitly unlocked/dev-flash lane.

## Core Device Restore Profile

If a wipe-capable flash becomes the easiest path, do not treat the target as a
full personal-data clone. Treat it as a curated Rabbit/OpenClaw core device
profile. The profile is documented in `docs/CORE_DEVICE_RESTORE_PROFILE.md` and
is supported by:

- `tools/restore-profile/capture-rabbit-core-profile.sh`
- `tools/restore-profile/validate-rabbit-core-readiness.sh`

The required app/device identity set is Tailscale, OpenClaw, Omi, Spotify,
Fennec as the default browser, launcher background, hotseat/workspace layout,
custom icon assets, keyguard/lockscreen state, and core Android settings.

The post-flash readiness pass is intentionally interactive for auth-bound
services. Tailscale must be logged in and VPN-approved, OpenClaw must be paired,
and Spotify must be logged in from a greydesk-projected device screen so Rodney
controls browser credentials directly.

## Short-Term Staging Updater

Build a package:

```bash
tools/live-update/build-rabbit-live-update-package.sh \
  --openclaw-apk "$OPENCLAW_ANDROID_APK"
```

Deploy in data-preserving runtime mode:

```bash
tools/live-update/deploy-rabbit-live-update.sh \
  --serial 919109A4J1600110804E \
  --package "$RABOBSTER_LIVE_UPDATE_OUT/<package>.tar.gz"
```

Runtime mode installs APK payloads with `pm install -r`, places the current side-button lock and boot-warm scripts under `/data/local/tmp`, attempts to start the temporary side-button watcher, records whether that watcher remains running, runs boot warm, and captures evidence under `$RABOBSTER_LIVE_UPDATE_EVIDENCE`.

When a production/system write is desired, add `--apply-system`. That mode attempts `adb remount` and copies the same scripts and init file into `/system`. It still applies runtime mode first, so a system-space failure does not prevent live validation.

The raw side-button watcher is a long-running `getevent` bridge used only for pocket-friendly double-tap lock. Hardware PTT is intentionally out of scope. On the current locked live device, treat the watcher as temporary runtime staging; the durable owner should be Android init through `r1_side_button.rc` in the next image or OTA.

## Medium-Term Signed Package Contract

Recommended path as of 2026-06-21: keep the r3/r4 runtime updater as the
data-preserving operational lane, then promote the same package contract into
signed OTA or image payloads. Do not bootloader-unlock a data-bearing live unit
just to gain `/system` persistence; use an unlocked dev device or signed
OTA/image validation for that lane.

The current package format now carries the bridge keys documented in `tools/live-update/SIGNED_PACKAGE_BRIDGE.md`: `package_format_version`, `channel`, `payload_type`, `signature_required`, `signature_scheme`, and `target_device`. The deployer rejects packages that do not target `rabbit_r1`, rejects unknown payload types, and refuses unsigned non-staging packages before touching the device.

The current package format also carries:

- `target_fingerprint` and `min_fingerprint`.
- per-file SHA-256 entries in `SHA256SUMS`.
- optional `SHA256SUMS.sig` from `--signing-key`.
- `RELEASE_CONTRACT.md` rollback and installer rules.

The installer rejects unsigned packages outside the staging channel, rejects
device/fingerprint mismatches unless explicitly forced, and writes a local
evidence bundle before and after mutation. After deployment, generate a
human-readable release summary before promotion:

```bash
tools/live-update/summarize-live-update-evidence.sh \
  "$RABOBSTER_LIVE_UPDATE_EVIDENCE/<stamp>-<serial>"
```

## Long-Term A/B OTA Lane

`device_rabbit_r1/device.mk` already includes `virtual_ab_ota.mk`, `update_engine`, `update_engine_sideload`, `update_verifier`, and `update_engine_client` debug support. That is the correct long-term direction, but it is not the fastest live-device path for today.

Before A/B OTA promotion, validate:

- bootctrl HAL behavior on the Rabbit R1.
- partition metadata and dynamic partition compatibility.
- postinstall behavior and rollback.
- update payload signing and key handling.
- data-preservation checks across slot switch and rollback.

## Acceptance Evidence

Minimum evidence for a usable staging update:

- ADB device identity and build fingerprint captured before and after.
- `pm install -r` result for OpenClaw and optional Tailscale.
- OpenClaw activity and `NodeForegroundService` start.
- OpenClaw activity and foreground service start successfully; Realtime Talk is the required voice experience and does not depend on hardware PTT.
- Boot warm log shows Tailscale connect attempt and OpenClaw warm start.
- `/data` remains intact; no fastboot erase, bootloader unlock, or userdata wipe command is used.
- If `--apply-system` is used, remount/copy/sync output is captured.
