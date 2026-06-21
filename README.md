# Splat-I Rabbit R1 OS

RaBobster OS build notes, Rabbit R1 integration files, visual assets, and verified screenshots for the Splat-I Rabbit R1 baseline.

This repository is meant to be usable by a broad audience, including students, first-time Android tinkerers, automation builders, and experienced developers. You do not need to already be an Android ROM expert to understand what is here. The short version is this:

- We took the Rabbit R1 hardware.
- We installed CipherOS on the Rabbit R1 and documented the expected install and first-boot behavior.
- We preserved the current RaBobster visual handoff, including Keyguard, workspace screenshots, and supplied icon artwork.
- We removed the failed custom launcher from the active device and repo path.
- We documented enough breadcrumbs that a person, or their own AI assistant, can rebuild the same baseline from public sources and repo-local assets.

If you are new to this kind of work, start with [docs/RABOBSTER_REBUILD_GUIDE.md](docs/RABOBSTER_REBUILD_GUIDE.md). It explains the project in plain language and includes a copy/paste prompt you can give to your own AI coding assistant.

## Current Baseline

- Primary branch: `main`
- Stable checkpoint: current `main`
- Target device: Rabbit R1
- Verified live-device baseline: CipherOS 7.0 ALHENA / Android 16 on `cipher_r1`
- Primary OS path: install the official CipherOS Rabbit R1 build, then apply the RaBobster handoff assets
- Historical/developer harness path: Android 15/Lineage-family source-build experiments, retained as integration context only
- Home/workspace package: `com.android.launcher3/.CipherLauncher`
- Removed launcher package: `io.splati.rabobster.launcher`
- Side button behavior: single tap wakes, double tap locks into Keyguard, long hold remains available for PTT behavior

## Repository Contents

- `device_rabbit_r1/` - Rabbit R1 device-tree overlay, keylayout, init scripts, system properties, boot animation, KeyHandler, and StepMotorControls integration.
- `harness/` - setup, slim, and verify helper scripts for source-build experiments.
- `docs/assets/brand/` - repo-local RaBobster image assets used by the current lockscreen/visual handoff.
- `docs/assets/icons/` - supplied RaBobster app icon artwork for Cipher home/workspace customization.
- `docs/assets/screenshots/` - sanitized RaBobster screenshots and contact sheets from the verified device state.

Large generated flash artifacts under `artifacts/` are intentionally ignored. They can be regenerated from the build tree.

Legacy CarrotOS harness screenshots were removed from the current tree so the repo visual evidence reflects the RaBobster build, not the pre-pivot recovery baseline.

## Visual Evidence

The current RaBobster screenshot set is tracked under `docs/assets/screenshots/`:

- `rabobster-keyguard-after-wake.png` - side-button wake path returning to Keyguard.
- `rabobster-workspace-page1.png` and `rabobster-workspace-page2.png` - current Cipher home/workspace pages after the failed launcher was removed.
- `rabobster-contact-sheet.png` - fresh sanitized contact sheet.

The lockscreen source image used for handoff is tracked as `docs/assets/brand/cute-rabobster-lockscreen-480x640.png`.

The supplied icon pack is tracked under `docs/assets/icons/`:

<img src="docs/assets/icons/rabobster-icon-contact-sheet.png" alt="RaBobster icon contact sheet" width="420">

## Acknowledgments

The cute bunny image was created by James Bubenik, based on Rodney's original warrior RaBobster image and concept.

- James Bubenik: <https://github.com/jamesbubenik>

### Current RaBobster Screens

<img src="docs/assets/screenshots/rabobster-keyguard-after-wake.png" alt="RaBobster keyguard after side-button wake" width="220">
<img src="docs/assets/screenshots/rabobster-workspace-page1.png" alt="RaBobster workspace page 1" width="220">
<img src="docs/assets/screenshots/rabobster-workspace-page2.png" alt="RaBobster workspace page 2" width="220">

More screenshots and contact sheets are documented in [docs/assets/screenshots/README.md](docs/assets/screenshots/README.md).

Asset provenance and redistribution cautions are tracked in
[docs/assets/ASSET_PROVENANCE.md](docs/assets/ASSET_PROVENANCE.md).

## Reproduction Summary

These steps reproduce the repo's public install/onboarding path. The fresh screenshots were captured from the current live Rabbit R1 on CipherOS Android 16 after the failed `io.splati.rabobster.launcher` package was removed.

1. Get the official CipherOS Rabbit R1 package from <https://sourceforge.net/projects/cipheros/files/CipherOS-7/r1/>. Known-good R1 packages follow the pattern `CipherOS-7.0-ALHENA-cipher_r1-YYYYMMDD-HHMM-BETA-OFFICIAL-VANILLA.zip`.
2. Read the release notes or flashing notes that come with the build. If upstream instructions differ from this README, follow upstream for the flash commands and partition list.
3. Verify the download before flashing. Use checksums published beside the release when available, or record your own checksum immediately after download and before copying the file between machines.
4. Use the Rabbit R1 web flasher to place the device into bootloader/fastboot mode.
5. Unlock the bootloader if needed. Expect a data wipe and an unlocked-device warning on later boots.
6. Install CipherOS with the official fastboot/update flow for the package you downloaded.
7. Let CipherOS complete first boot, then confirm the home handler is `com.android.launcher3/.CipherLauncher`.
8. Apply the RaBobster handoff: set the Keyguard image from `docs/assets/brand/`, apply the supplied icon artwork from `docs/assets/icons/`, keep CipherLauncher as home, and verify side-button wake/lock behavior.
9. Compare the device against `docs/assets/screenshots/`.

The current repo no longer includes or installs the discarded custom launcher APK.

The older source-build harness is not the public install path. It remains useful for developers who need to inspect or rebuild integration pieces, but the public onboarding lane starts from the official CipherOS Android 16 Rabbit R1 release.

## Public Release Notes

This repository is documentation, integration scaffolding, and visual evidence. It does not provide a ready-made RaBobster APK or a complete public ROM download. Use the official CipherOS Rabbit R1 release as the OS base.

Do not publish private signing keys, account tokens, device identity files, NV partitions, private recovery dumps, or generated flash images in forks or issue reports.

Some materials referenced by this repo come from third-party or vendor projects, including CipherOS, Rabbit R1 platform work, Android platform components, and contributed artwork. Keep their upstream license, attribution, and release-note requirements intact when you redistribute changes.

## Licensing And Provenance

Unless a file or notice states otherwise, original repository code,
documentation, scripts, and configuration are licensed under the Apache License,
Version 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

This repository does not grant rights to CipherOS, LineageOS, Android/AOSP,
Rabbit R1, Rabbit Inc. marks, MediaTek components, vendor blobs, proprietary
APKs or libraries, third-party logos, or logo-derived icons. Those materials
remain under their upstream owners' terms. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and
[docs/assets/ASSET_PROVENANCE.md](docs/assets/ASSET_PROVENANCE.md) before
redistributing assets or generated device images.

## Useful Checks

```bash
git status --short --branch
rg -n --hidden --glob '!.git/**' --glob '!*.png' --glob '!*.jpg' --glob '!*.zip' --glob '!*.apk' --glob '!*.img' -i '(api[_-]?key|secret|token|password|authorization:|bearer |-----BEGIN (RSA|OPENSSH|PRIVATE)|ghp_|github_pat_|sk-)' .
```
