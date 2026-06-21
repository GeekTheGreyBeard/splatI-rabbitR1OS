# Third-Party Notices

This file records known third-party ownership and licensing boundaries for
the public handoff repository. It is not a complete legal audit. If a
specific upstream file carries its own copyright or license header, that
header controls for that file.

## Repository License Boundary

The top-level `LICENSE` applies to original repository code, documentation,
scripts, and configuration unless a file or notice states otherwise.

The Apache-2.0 grant does not apply to materials that are merely referenced,
described, required from upstream, captured in screenshots, or retained under
their own upstream terms.

## Android, AOSP, LineageOS, And CipherOS

This repository describes and/or contains integration scaffolding related to
Android, the Android Open Source Project, LineageOS-style device trees, and
CipherOS. Those projects remain under their respective upstream licenses,
copyrights, notices, and contribution rules.

This repository does not redistribute a complete CipherOS build, a complete
LineageOS build, or a complete Android/AOSP distribution. Rebuilders should
obtain OS source, release images, manifests, and build dependencies from the
official upstream locations and follow those upstream license terms.

Some Android-derived files in this repository already include Apache-2.0
headers from AOSP, LineageOS, CyanogenMod, or RabbitEscape-era sources.
Those file-local notices are preserved and should remain with the files.

## Rabbit R1, Rabbit Inc., And Device-Specific Materials

Rabbit R1, Rabbit Inc. names, device appearance, product identifiers,
flashing flows, and any related trademarks remain owned by their respective
owners. Their mention here is descriptive.

This repository should not be read as granting rights to Rabbit firmware,
device identity files, proprietary recovery dumps, signed production images,
or other non-public device materials.

## MediaTek, Vendor Blobs, Proprietary APKs, And Libraries

MediaTek names, chip/platform references, vendor firmware, proprietary
binary blobs, proprietary APKs, proprietary native libraries, and similar
closed materials remain under their upstream owners' terms.

Where this repository references proprietary files or extraction workflows,
that reference is for rebuild documentation and integration scaffolding. Do
not redistribute proprietary blobs, APKs, libraries, device identity data, or
generated flash images unless you have the rights to do so.

## Bootanimation Files

`device_rabbit_r1/bootanimation/` contains boot animation archive files in
the working tree. The active `bootanimation.zip` is a 480x480 PatriciAI logo
animation generated from the PatriciAI web interface logo asset at
`/run/media/gtgb/GTGB-Files/Projects/RASiTechnical/patriciAI/patriciAIWebInterface/deploy/assets/patriciai-logo.png`.
The older backup archives in that folder predate this replacement and remain
conservative use / pending confirmation unless a later notice documents clearer
rights.

## Visual Assets, Screenshots, Logos, And Icons

Visual asset provenance is tracked in `docs/assets/ASSET_PROVENANCE.md`.
That file distinguishes repo-created RaBobster artwork, James Bubenik's cute
bunny image, generated or derived workspace icons, screenshots, bootanimation
files, and third-party logo/icon references.

Third-party logos and product-derived icons remain subject to the terms and
trademark rules of their owners. Logo-derived icons should be replaced,
removed, or confirmed before broad public redistribution if their permission
status is unclear.
