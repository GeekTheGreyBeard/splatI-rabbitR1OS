# Asset Provenance

This file tracks known provenance and redistribution caution for visual
assets in this repository. It is intentionally conservative: unknown
permission is marked as pending confirmation rather than assumed open.

The top-level Apache-2.0 license covers original repository code,
documentation, scripts, and configuration unless otherwise stated. It does
not automatically cover third-party logos, trademarks, screenshots of
third-party software, proprietary platform assets, or artwork whose separate
permission has not been confirmed.

| Asset group | Files / examples | Known source | Current repo use | Permission status | Conservative action before broad distribution |
| --- | --- | --- | --- | --- | --- |
| Rodney / RaBobster concept | `docs/assets/icons/Rabobster.png`; RaBobster visual concept referenced by docs | Rodney's original warrior RaBobster image and concept | Project identity, workspace icon source, screenshot context | Pending confirmation for public asset licensing; concept attribution known from repo docs | Confirm explicit public license or replace with newly licensed original art before broad redistribution |
| James cute bunny image | `docs/assets/brand/cute-rabobster-lockscreen-480x640.png`; `docs/assets/icons/cute_RaBobster.png`; screenshots containing the image | Created by James Bubenik based on Rodney's original warrior RaBobster image and concept | Lockscreen handoff source image and icon artwork | Creator and derivation are documented; exact redistribution license is not documented in-repo | Confirm James's permission/license and Rodney's approval for the underlying derivative concept before broad redistribution |
| Generated / derived workspace icons | `browser.png`, `calc.png`, `calendar.png`, `camera.png`, `clock.png`, `files.png`, `gallery.png`, `messaging.png`, `phone.png`, `settings.png`, `terminal.png`, `weather.png`, `openclaw.png`, contact sheets | Supplied RaBobster app icon artwork; some may be generated, repo-created, product-inspired, or logo-derived | Cipher home/workspace customization and visual evidence | Mixed / pending confirmation; exact generation prompts, source references, and licenses are not documented here | Keep for repo-local handoff evidence; replace or relicense each icon with documented original/open artwork before broad distribution |
| Screenshots | `docs/assets/screenshots/*.png` | Captured from the verified Rabbit R1 running CipherOS 7.0 ALHENA / Android 16 on 2026-06-20, with carrier and Wi-Fi identifiers redacted before commit | Visual evidence for the reproducible device state | Repo-created captures, but they may show CipherOS/Android UI, third-party icons, product marks, and RaBobster artwork | Use as documentation evidence; avoid implying ownership of captured third-party UI or marks |
| Bootanimation files | `device_rabbit_r1/bootanimation/bootanimation.zip`, `.bak.c1`, `.bak.black480` | Present in the device tree working copy; exact artwork/source lineage not documented in this provenance file | Device-tree boot animation assets | Pending confirmation | Confirm origin and license, replace with documented original/open boot animation, or remove before broad distribution if rights remain unclear |
| Third-party logos / icons | `f-droid.png`, `tailscale.png`, `OMI.png`, and any product/logo-derived workspace icon | Third-party product or project identity may be represented | Workspace icon customization and screenshots | Pending confirmation; trademarks and logo artwork remain with upstream owners | Confirm each upstream brand asset policy/license or replace with neutral, original icons before broad distribution |
| Android / CipherOS / Rabbit / MediaTek marks visible in docs or screenshots | Screenshots and textual references across `README.md`, `docs/`, and asset docs | Respective upstream owners | Descriptive project documentation | Descriptive use only; no trademark ownership claimed | Keep wording descriptive and do not use marks as branding for unrelated distribution |

## Notes For Maintainers

- Do not assume an image is Apache-2.0 just because it lives in this repo.
- Keep generated flash artifacts, proprietary blobs, APKs, private dumps,
  device identity files, and signing keys out of the public repository.
- When replacing uncertain assets, prefer newly created artwork with a clear
  license and keep source prompts or design notes with the asset.
- When adding third-party brand assets, record the upstream brand guideline or
  license URL in this file at the time the asset is added.
