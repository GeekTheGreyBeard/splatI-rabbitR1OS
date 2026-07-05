# Rabbit/OpenClaw Core Device Restore Profile

This profile defines the practical wipe-tolerant lane for a Rabbit R1 managed as
RaBobster/OpenClaw hardware. It is not a full forensic clone of Android user
data. It restores the device identity, required apps, launcher state, visual
assets, and post-flash readiness checks needed for the device to be usable.

## Scope

Required core apps:

- Tailscale: `com.tailscale.ipn`
- OpenClaw: `ai.openclaw.app`
- Omi: current package may be `com.friend.ios` or `com.friend.ios.dev`
- Spotify: `com.spotify.music`
- Fennec: `org.mozilla.fennec_fdroid`

Required device identity state:

- Fennec set as the default browser where Android allows it.
- User/home wallpaper and lockscreen wallpaper restored.
- Hotseat icon membership restored.
- Homescreen and workspace icon membership and placement restored.
- Custom icon images restored.
- Keyguard/lockscreen settings and image restored where Android allows it.
- Core system and user settings restored.

Required human-auth readiness:

- Tailscale must be logged in and VPN approved.
- OpenClaw must be paired/connected through its normal setup flow.
- Spotify must be logged in.
- Browser-based login flows must be projected from greydesk so Rodney can
  control authentication directly.

## Known Good Source Artifacts

Prior restore source:

`$RABOBSTER_RESTORE_SOURCE/r1RestoreAfterBootAnimationFlash-20260621T0950/`

Important reusable artifacts:

- APK archive:
  - `apks/com.tailscale.ipn_576.apk`
  - `apks/omi-dev-release.apk`
  - `apks/org.mozilla.fennec_fdroid_1520020.apk`
  - `apks/patriciai-2026.6.2-thirdParty-debug.apk`
- Spotify APK source:
  - `$RABOBSTER_APK_ARCHIVE/spotify-9.1.58.1567.apk`
- Launcher/icon databases:
  - `db/launcher_3_by_3.restored.db`
  - `db/app_icons.restored.db`
  - `db/device-favorites-final-with-tailscale.txt`
- Wallpaper helper:
  - `wallpaperHelper/build/RaBobsterLockWallpaperHelper.apk`
- Verification examples:
- `verification-after-restore.txt`
- `wallpaper-state-after-restore.txt`
- `side-button-runtime-after-restore.txt`

Additional icon/layout artifacts:

- `$RABOBSTER_ARTIFACTS/cipherCustomIcons-20260620T133139-0600/`
- `$RABOBSTER_ARTIFACTS/cipherWorkspaceUpdate-20260620T134153-0600/`
- `$RABOBSTER_ARTIFACTS/cipherOmiIcon-20260620T1506-0600/`

## Pre-Flash Capture

Run before any wipe-capable flash command:

```bash
tools/restore-profile/capture-rabbit-core-profile.sh \
  --serial 919109A4J1600110804E
```

The capture script records:

- device identity, build fingerprint, slot, and boot state
- installed packages and paths
- core package dumps
- Android `settings` namespaces
- preferred/default browser evidence
- wallpaper service state
- launcher/package UI XML and screenshots
- best-effort APK pulls for core apps
- best-effort launcher database pulls when Android permissions allow it

The script does not perform destructive actions.

## Flash Gate

Before flashing, the operator must confirm all of the following in the evidence
directory:

- `device-identity.txt` and `build-fingerprint.txt` exist.
- `packages-third-party.txt` exists.
- `core-packages-summary.txt` identifies every required package as installed or
  intentionally restored from the known-good APK archive.
- `settings/` contains global, secure, and system dumps.
- `screens/` contains at least home and lockscreen screenshots.
- `FLASH_GATE.md` has no unresolved hard failures.

Do not proceed if a flash script includes `fastboot -w`, `fastboot erase
userdata`, `recovery --wipe_data`, or `format data` unless the restore package
and readiness runbook are already prepared.

## Restore Order

1. Boot the flashed image.
2. Enable ADB and record the post-flash baseline.
3. Install required APKs from the versioned archive.
4. Grant runtime permissions for OpenClaw and Omi.
5. Restore device names and core Android settings.
6. Restore wallpaper and lockscreen image with the helper APK when needed.
7. Restore launcher/icon databases or apply the documented SQL transforms.
8. Set Fennec as default browser where Android allows it:
   `cmd role add-role-holder android.app.role.BROWSER org.mozilla.fennec_fdroid`.
9. Start/enable Rabbit/OpenClaw runtime helpers.
10. Run readiness validation.
11. Project the screen from greydesk and complete interactive auth:
    Tailscale, OpenClaw, then Spotify.
12. Capture final screenshots and evidence summary.

## Readiness Validation

Run after restore:

```bash
tools/restore-profile/validate-rabbit-core-readiness.sh \
  --serial 919109A4J1600110804E
```

Pass criteria:

- Required core apps are installed.
- OpenClaw activity and foreground service can start.
- OpenClaw Realtime Talk is available through the app; hardware PTT is not part of the readiness target.
- Tailscale package is installed and the VPN/login state is recorded.
- Fennec package is installed and default-browser evidence is captured.
- Omi and Spotify packages are installed.
- Launcher, wallpaper, keyguard/settings, and screenshots are captured.
- Interactive auth checklist is explicit for Tailscale, OpenClaw, and Spotify.

## Boundary

This profile does not promise recovery of arbitrary third-party private data
under `/data/data`. It is designed for the curated core identity of the managed
Rabbit/OpenClaw device, with custom apps and visual/device state kept
repeatable through versioned artifacts and evidence.
