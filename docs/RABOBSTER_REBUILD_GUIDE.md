# Rebuilding The RaBobster Rabbit R1 OS

This guide is for people who want to recreate the RaBobster Rabbit R1 OS baseline from this repository. It is written for a mixed audience: students, new automation builders, people trying to break into AI work, and experienced Android developers who just want the facts without hunting through old notes.

You can follow it yourself, or you can give it to your own AI coding assistant and ask that assistant to walk you through the process.

## What This Project Is

The Rabbit R1 is a small Android-based device. This project turns a CipherOS Rabbit R1 install into a reproducible RaBobster visual and control baseline without carrying the failed custom launcher that was removed from the active device.

James Bubenik created the cute bunny image based on Rodney's original warrior RaBobster image and concept. His GitHub profile is <https://github.com/jamesbubenik>. That credit matters because the approachable visual direction is part of what makes the device feel understandable and welcoming to new builders.

In practical terms, this repository contains:

- A Rabbit R1 device-tree overlay for a LineageOS 21 / Android 14 GSI-style build path.
- System configuration for a small-device Rabbit R1 home/workspace experience.
- No custom RaBobster launcher APK. The failed launcher was removed from the device and repo path.
- Supplied RaBobster icon artwork for the Cipher home/workspace.
- A side-button helper that supports pocket-safe locking.
- Verification scripts and build notes.
- Screenshots showing the expected result.

The project is not a normal Android app project. It is closer to a small Android operating-system integration project. That means you are building and flashing system images, not just installing an APK.

## Start With CipherOS

RaBobster starts from CipherOS on the Rabbit R1. This repository does not ship a complete RaBobster ROM download or a RaBobster APK.

Use the official release path for a normal rebuild:

- Download the official CipherOS Rabbit R1 build from <https://sourceforge.net/projects/cipheros/files/CipherOS-7/r1/>. The CipherOS project also documents Rabbit R1 support at <https://cipheros.org.in/blog/cipheros-on-rabbitr1>.

There is also a source-build helper at `harness/setup_cipheros.sh`, but treat it as developer scaffolding, not the beginner path. It follows the public CipherOS source setup that was available during this project and may not reproduce the exact Android 16 release package if newer Rabbit R1 device sources are not public.

The helper uses these public upstreams:

- CipherOS manifest: <https://github.com/CipherOS/android_manifest>
- Rabbit R1 device tree: <https://github.com/techyminati/android_device_rabbit_r1>
- Rabbit R1 vendor blobs: <https://github.com/techyminati/proprietary_vendor_rabbit_r1>
- Rabbit R1 kernel source: <https://github.com/techyminati/alps-4.19>

## Installing CipherOS

Expect the CipherOS install to be the hardest part of the process. Read the CipherOS build/release notes for the exact image package you are using, then use this as the practical checklist for what will happen on the Rabbit R1.

1. Install Android platform-tools so `adb` and `fastboot` are available.
2. Use a Chromium-based browser and the Rabbit R1 web flasher at <https://rabbit-hmi-oss.github.io/flashing/> to enter bootloader/fastboot mode.
3. Unlock the bootloader when required. Unlocking can erase the device.
4. Flash the CipherOS package or images exactly as documented by the CipherOS/R1 release you are using.
5. Leave the device connected during first boot. First boot after flashing can take several minutes.
6. If the device shows a message that it is not trusted because the bootloader is unlocked, do not panic. That warning is expected on an unlocked device. It is safe to ignore it and let the Rabbit R1 continue booting into CipherOS.
7. Once CipherOS boots, complete the initial setup enough to reach the Cipher home/workspace.

After CipherOS is running, this repository's RaBobster work begins: apply the Keyguard artwork, workspace layout, supplied icon artwork, and side-button behavior, then compare the result against the screenshots in this guide.

## What You Should See When It Works

These screenshots are the target for the current live-device baseline. They were freshly captured from a Rabbit R1 running CipherOS 7.0 ALHENA / Android 16 after `io.splati.rabobster.launcher` was uninstalled.

The repo also preserves a LineageOS 21 / Android 14 GSI build harness. In plain language: the screenshots show the cleaned device state we are handing off now, and the build harness shows the path for reproducing the OS integration work without bundling the discarded launcher.

Your rebuilt device does not have to be pixel-perfect in every status icon, but the major behavior should match.

### Keyguard

Single tapping the side button should wake the device back to the Keyguard screen. Double tapping should lock the device for pocket carry.

<img src="assets/screenshots/rabobster-keyguard-after-wake.png" alt="RaBobster keyguard after side-button wake" width="240">

### Home And Workspace

The home/workspace screens should show the cleaned Cipher home surface with the warrior RaBobster background rather than the discarded custom launcher.

<img src="assets/screenshots/rabobster-workspace-page1.png" alt="RaBobster workspace page 1" width="240">
<img src="assets/screenshots/rabobster-workspace-page2.png" alt="RaBobster workspace page 2" width="240">

### Contact Sheets

Use these as quick visual references when checking another build.

<img src="assets/screenshots/rabobster-contact-sheet.png" alt="RaBobster screenshot contact sheet" width="320">

## Supplied Icon Artwork

The RaBobster icon pack lives in `docs/assets/icons/`.

<img src="assets/icons/rabobster-icon-contact-sheet.png" alt="RaBobster icon contact sheet" width="420">

Use these icons for the Cipher home/workspace customization. They are image assets, not an APK. The verified device applied them to Cipher's existing Launcher3/CipherLauncher workspace and icon cache.

## Important Safety Notes

Flashing Android system images can break a device temporarily. It can erase data. If you flash the wrong image to the wrong partition, you may need recovery tools to get back.

Before you begin:

- Back up anything important on the device.
- Make sure you know how to reach bootloader and fastbootd mode.
- Make sure `adb` and `fastboot` can see the device.
- Do not flash production devices you cannot afford to recover.
- Do not publish private signing keys, generated flash images, device identity files, account credentials, or private recovery dumps.

This repository intentionally does not include private signing or device-identity material.

## What You Need

For the official CipherOS install path, you will need:

- A computer with a Chromium-based browser for the Rabbit R1 web flasher.
- Android platform-tools, especially `adb` and `fastboot`.
- A Rabbit R1 device that you are allowed to modify.
- Time for flashing and first boot.

For source-build experiments, you will also need:

- A Linux build machine.
- At least 250 GB of free disk space.
- Android build dependencies for CipherOS.
- `git` and `repo`.

If you are new, the hardest part is usually not the code. It is getting the device into the right flashing mode and understanding the first boot behavior.

## The Main Breadcrumbs

These are the most important files and folders:

- `README.md` - the short project overview.
- `device_rabbit_r1/` - the Rabbit R1 device-tree overlay and OS integration files.
- `device_rabbit_r1/rootdir/system/bin/rabobster-side-button` - the side-button lock helper.
- `device_rabbit_r1/rootdir/system/etc/init/r1_side_button.rc` - init service for the side-button helper.
- `device_rabbit_r1/rootdir/system/etc/init/r1_kiosk.rc` - kiosk/system behavior setup.
- `device_rabbit_r1/overlay/` - Android framework and settings overlays.
- `harness/setup_cipheros.sh` - setup helper for CipherOS source-tree experiments, not a replacement for the official R1 release package.
- `harness/setup_lineage.sh` - older setup helper for the Lineage build tree, retained as historical context.
- `harness/slim_lineage.sh` - removes packages that are not useful for this small-device kiosk build.
- `harness/verify_lineage_state.sh` - checks whether the build tree still matches the expected state.
- `docs/assets/icons/` - supplied RaBobster app icon artwork for the Cipher workspace.
Generated flash artifacts and private working notes are intentionally not part of the public handoff. Use the official CipherOS release package first, and regenerate local build outputs in your own workspace if you choose the source-build path.

## Suggested AI Assistant Prompt

If you are using your own AI assistant, start with this prompt:

```text
You are helping me rebuild the RaBobster Rabbit R1 OS from this repository.

Read README.md first, then docs/RABOBSTER_REBUILD_GUIDE.md, then inspect the harness scripts and device_rabbit_r1 folder. Treat this as an Android OS integration project, not a normal Android app.

Goal:
Reproduce the RaBobster Rabbit R1 OS baseline shown in docs/assets/screenshots. The expected result is a Rabbit R1 that does not carry the failed io.splati.rabobster.launcher package, shows the RaBobster Keyguard artwork, uses the Cipher home/workspace surface, keeps Android system surfaces reachable, and supports side-button behavior where single tap wakes, double tap locks, and long hold remains available for PTT.

Constraints:
- Do not invent missing signing keys or device files.
- Do not commit keystores, account credentials, generated flash images, NV partitions, or private dumps.
- Ask before destructive flashing steps.
- Start by installing the official CipherOS Rabbit R1 build unless I explicitly ask for a source-build experiment.
- Treat the unlocked-bootloader trust warning as expected after unlock; let the device continue booting.
- Before any build, explain which files you are using and why.
- Before flashing, run the repo verification scripts and show me the result.
- After flashing, compare the device against the screenshots in docs/assets/screenshots.

Start by summarizing the repo layout and giving me a step-by-step plan.
```

That prompt tells your assistant what the project is, what success looks like, and what not to do.

## Build Flow At A High Level

The exact Android build environment can vary, but the intended flow is:

1. Clone this repository.
2. Download the official CipherOS Rabbit R1 build.
3. Read the release notes or flashing notes that come with that build.
4. Use the Rabbit R1 web flasher to reach fastboot/bootloader mode.
5. Unlock the bootloader if needed, understanding that this can wipe the device.
6. Flash the CipherOS package or images using the instructions for that build.
7. Allow the unlocked-device trust warning to pass and wait for first boot.
8. Confirm the device reaches CipherOS and the home handler is `com.android.launcher3/.CipherLauncher`.
9. Apply the RaBobster Keyguard image, workspace layout, and icon assets from this repository.
10. Boot the device and compare against the screenshots in this guide.

## What To Check After Boot

After the device boots:

1. Confirm `io.splati.rabobster.launcher` is not installed.
2. Confirm the home handler is `com.android.launcher3/.CipherLauncher`.
3. Confirm the RaBobster home/workspace background is visible.
4. Confirm Quick Settings can still be reached.
5. Confirm Settings can still be opened.
6. Confirm the side button behavior:
   - Single tap wakes to Keyguard.
   - Double tap locks the screen.
   - Long hold is still available for PTT behavior.
7. Confirm the lockscreen image matches the RaBobster lockscreen evidence.
8. Confirm the supplied icon artwork appears on the Cipher workspace.

## Common Confusions

### Is this a complete launcher source repo?

No. The failed custom launcher was removed from the device and from this repo path. This handoff is about the Rabbit R1 OS integration, Keyguard artwork, workspace evidence, and side-button behavior.

### Does this repository provide an APK?

No. The current RaBobster path uses CipherOS and Cipher's existing home/workspace. The icon pack and screenshots are image assets and evidence, not a packaged Android app.

### Is the unlocked-device trust warning bad?

No. After unlocking the Rabbit R1 bootloader, the device can warn that it is not trusted because it is unlocked. That warning is expected. Let it continue booting; it can still boot into CipherOS normally.

### Are the old CarrotOS screenshots still the target?

No. The old CarrotOS-era screenshots were removed from the current tree because they described an earlier recovery baseline. The current target is the RaBobster evidence under `docs/assets/screenshots/`.

### Why are there no signing keys, generated images, or device identity files?

Signing keys, generated flash images, and device identity files should not be published in a public rebuild guide. Use your own local development keys for lab builds, regenerate images locally, and do not share private device dumps in issues or forks.

### Why so many notes?

This project was built through real device work, recovery work, Android build-system work, and UI verification. The notes preserve the trail so another person or AI assistant can retrace the work instead of starting over.

## Success Criteria

You have reproduced the baseline when:

- The Rabbit R1 boots successfully.
- The discarded `io.splati.rabobster.launcher` package is absent.
- The Cipher home/workspace appears with the RaBobster visual baseline.
- The supplied RaBobster icon artwork is present on the Cipher workspace.
- The lockscreen/Keyguard behavior matches the screenshots.
- The side-button lock behavior works.
- Android system surfaces remain reachable.
- No private keys, credentials, generated flash images, NV partitions, or device identity files were added to your copy of the repo.
- Your build process can be repeated by someone else using the same documented steps.
