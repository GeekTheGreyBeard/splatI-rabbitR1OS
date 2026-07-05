# Rabbit/OpenClaw Signed Package Bridge

This directory owns the staging bridge between the r3 runtime updater and durable ROM or OTA updates. It does not contain production signing material.

## Package Contract

Every package is a tarball with:

- `manifest.properties`
- `SHA256SUMS`
- `payload/`
- optional `SHA256SUMS.sig`

Required manifest keys:

- `name=rabbit-openclaw-live-update`
- `package_format_version=1`
- `channel=staging`, `internal`, or a later release channel
- `payload_type=runtime`, `system`, `ota`, or `ab_ota`
- `signature_required=false` only for `channel=staging`
- `signature_scheme=sha256sums-detached`
- `target_device=rabbit_r1`

The current builder emits these fields. The current deployer rejects packages unless `target_device=rabbit_r1`, `payload_type` is one of the known bridge types, and non-staging packages include `SHA256SUMS.sig`.

## Shortest Practical Bridge

1. Keep r3 updates as `channel=staging` and `payload_type=runtime`.
2. Use the same payload layout for the next image-backed `/system` bootstrap files.
3. When a real signing key is approved, sign `SHA256SUMS` as `SHA256SUMS.sig` and set `channel` to a non-staging value.
4. For image-backed updates, switch `payload_type` to `system`.
5. For update-engine packages, switch `payload_type` to `ab_ota` and store the signed payload metadata under `payload/ota/`.

This lets today's data-preserving updater test OpenClaw, Tailscale, Realtime Talk app readiness, and boot-warm behavior without pretending it is a complete OTA. The same manifest keys can then gate the later durable updater.

## Acceptance Evidence

For staging runtime updates:

- host package SHA-256
- on-device `sha256sum -c SHA256SUMS`
- before/after device identity and build fingerprint
- OpenClaw and optional Tailscale install results
- OpenClaw activity and foreground service start
- boot-warm log
- proof no bootloader unlock, fastboot erase, userdata wipe, or production push was used

For non-staging signed packages, add:

- public signing key ID
- detached signature verification output
- package channel and payload type
- rollback or recovery instructions for every mutable path
