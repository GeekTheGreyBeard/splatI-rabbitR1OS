# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include build/make/target/board/BoardConfigGsiCommon.mk

BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Append device-specific system properties to /system/build.prop (notably
# qemu.hw.mainkeys=1 to suppress the SystemUI nav bar — see system.prop).
# my-dir doesn't resolve in BoardConfig.mk, hence the hardcoded path.
TARGET_SYSTEM_PROP := device/rabbit/r1/system.prop

# Hijack Lineage's bootanimation. vendor/lineage/bootanimation/Android.mk
# only generates from .tar if TARGET_BOOTANIMATION is unset; setting it here
# makes the LOCAL_BUILT_MODULE rule cp our prebuilt zip into place instead.
# This is the supported override hook — PRODUCT_COPY_FILES collides with the
# module's own install rule.
TARGET_BOOTANIMATION := device/rabbit/r1/bootanimation/bootanimation.zip

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic

# A/B
# BOARD_BUILD_SYSTEM_ROOT_IMAGE is obsolete in Android 14+ — system-as-root is implicit
# BOARD_BUILD_SYSTEM_ROOT_IMAGE := false
BOARD_USES_RECOVERY_AS_BOOT := true
AB_OTA_UPDATER := true

AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    product \
    system \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vendor

# TODO(b/111434759, b/111287060) SoC specific hacks
BOARD_ROOT_EXTRA_SYMLINKS += /vendor/lib/dsp:/dsp
BOARD_ROOT_EXTRA_SYMLINKS += /mnt/vendor/persist:/persist
BOARD_ROOT_EXTRA_SYMLINKS += /vendor/firmware_mnt:/firmware

# TODO(b/36764215): remove this setting when the generic system image
# no longer has QCOM-specific directories under /.
BOARD_SEPOLICY_DIRS += build/make/target/board/generic_arm64/sepolicy

# Sepolicy
# device/mediatek/sepolicy is not in the LineageOS manifest — for a vanilla GSI
# we can rely on the generic sepolicy already pulled in via BOARD_SEPOLICY_DIRS above.
# include device/mediatek/sepolicy/BoardSEPolicyConfig.mk

# Inherit the proprietary files
include vendor/rabbit/r1/BoardConfigVendor.mk

# Lineage build-system glue (PATH_OVERRIDE_SOONG, KERNEL_MAKE_*, FMRadio namespace
# logic). Originally absent because the RabbitHoleEscapeR1 tree was designed for
# AOSP GSI, not Lineage; we wire it in here so the Lineage soong rules resolve.
include vendor/lineage/config/BoardConfigLineage.mk
