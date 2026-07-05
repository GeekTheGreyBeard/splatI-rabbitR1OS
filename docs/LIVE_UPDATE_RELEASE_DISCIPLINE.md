# Rabbit/OpenClaw Live Update Release Discipline

Owner lane: QuarterMaster release and evidence discipline.

This document defines the release gate around the Rabbit/OpenClaw live-update lane. It is intentionally separate from the OTA/runtime implementation files. The goal is to make each staging update auditable before anyone considers a production or persistent-system path.

## Scope

In scope:

- Acceptance checklist for staging live updates.
- Release manifest shape for package review.
- Evidence bundle summary requirements.
- Rollback notes for runtime and attempted system writes.
- Completion criteria for closing a live-update run.

Out of scope:

- Production deployment.
- Signing-key handling.
- OTA payload generation.
- Bootloader unlock, userdata wipe, or fastboot erase flows.
- Changes to `device_rabbit_r1/` implementation files.

## Release Manifest Shape

Every release candidate must include a package-level `manifest.properties` and `SHA256SUMS`. The manifest may stay properties-formatted for the current staging lane, but the release review must treat these fields as required:

```properties
name=rabbit-openclaw-live-update
version=<human release or UTC build id>
built_at_utc=<YYYYMMDDTHHMMSSZ>
channel=staging
payload_type=runtime|system|ota|ab_ota
target_device=rabbit_r1
target_serial=<serial or ANY_STAGING_DEVICE>
target_fingerprint=<exact ro.build.fingerprint or ANY_STAGING_FINGERPRINT>
min_fingerprint=<oldest accepted fingerprint or empty for staging>
openclaw_package=ai.openclaw.app
openclaw_activity=ai.openclaw.app/.MainActivity
openclaw_service=ai.openclaw.app/.NodeForegroundService
tailscale_package=com.tailscale.ipn
contains_openclaw_apk=true|false
contains_tailscale_apk=true|false
rollback_plan=runtime_reinstall|runtime_remove|system_restore|ota_slot_rollback
requires_userdata_wipe=false
requires_bootloader_unlock=false
signature_status=unsigned_staging|signed_staging|signed_production
```

Current staging packages are allowed to omit future signing/fingerprint keys only when the evidence summary records that omission. Production candidates must not omit them.

`SHA256SUMS` must cover every mutable file in the package, including APKs, scripts, init files, and manifest fragments. The package tarball itself must also have a host-side `.sha256` file.

## Acceptance Checklist

A staging live-update run is acceptable only when the evidence bundle proves all required items below.

- Package checksum verified on host and device.
- Device serial, model, and build fingerprint captured before mutation.
- Update path did not use bootloader unlock, fastboot erase, userdata wipe, or production signing material.
- OpenClaw install result captured when an APK is included.
- OpenClaw activity start result captured.
- `ai.openclaw.app/.NodeForegroundService` start result captured.
- Realtime Talk remains the required voice experience; hardware PTT is not a release gate.
- Boot warm result captured, including Tailscale connect attempt and OpenClaw warm start logs when available.
- Package/device state captured after mutation.
- `/data` preservation evidence captured by before/after package state or equivalent proof.
- If `--apply-system` was used, remount, copy, chmod, sync, and failure output are captured.
- A human-readable evidence summary exists in the evidence directory.

The update is not complete if any required evidence file is missing, empty, or only contains a command prompt without result output.

## Evidence Bundle Summary

Each deploy run should produce one evidence directory under the configured evidence root. After deployment, run:

```bash
tools/live-update/summarize-live-update-evidence.sh <evidence-dir>
```

The helper writes `summary.md` in the same evidence directory. That summary is the first review artifact for release triage. It must include:

- Evidence directory path and UTC summary timestamp.
- Package hash, when present.
- Before/after device identity and build fingerprint.
- Pass, warn, or fail status for required evidence files.
- Install/start/boot-warm excerpts.
- System-write status when `--apply-system` evidence is present.
- Rollback notes for the observed payload type.
- Final completion criteria.

Keep raw command output in the evidence directory. Do not paste secrets, personal account details, private tokens, or unrelated logs into the summary.

## Rollback Notes

Runtime staging rollback:

- Reinstall the previous known-good OpenClaw APK with `pm install -r -d` if package downgrade is allowed.
- Stop temporary side-button watchers by killing the PID from `/data/local/tmp/rabobster-side-button.pid` when present.
- Remove temporary runtime files and staging paths under `/data/local/tmp/rabobster-live-update*`, `/data/local/tmp/rabobster-side-button*`, and `/data/local/tmp/rabobster-boot-warm*`.
- Re-run the previous boot warm path or reboot if the validation owner needs a clean process state.
- Capture post-rollback package state and service start evidence.

Attempted system-write rollback:

- If remount failed before writes, record the failure and treat rollback as not required.
- If any `/system` file was changed, restore the previous file from a captured backup or from the last validated image artifact.
- Reapply original modes, run `sync`, reboot, and capture package/service evidence.
- If original system files are unavailable, stop and mark the lane blocked rather than improvising production recovery.

OTA or A/B rollback:

- Use the signed OTA rollback mechanism or slot rollback plan for that package.
- Capture current slot, target slot, update engine status, and rollback result.
- Do not mix runtime cleanup with OTA rollback unless the release owner records both scopes explicitly.

## Completion Criteria

A live-update release candidate can be marked complete when:

- The package path and package SHA256 are recorded.
- The manifest review has no production-blocking omissions.
- The evidence bundle summary reports no failed required checks.
- Any warnings are explicitly accepted by the release owner with a short reason.
- Rollback notes match the payload type and observed device state.
- No production deployment was attempted from the staging lane.
- The final report lists changed repo files, evidence directory, checks run, and remaining blockers.

## Reporting Template

Use this shape for the final release/evidence note:

```text
Live-update lane result: pass|warn|fail
Package: <path>
Package SHA256: <hash>
Evidence: <evidence-dir>/summary.md
Device: <serial>, <model>, <fingerprint>
Payload type: <runtime|system|ota|ab_ota>
Acceptance: <short pass/fail notes>
Rollback: <short applicable note>
Production touched: no
Blockers: <none or list>
```
