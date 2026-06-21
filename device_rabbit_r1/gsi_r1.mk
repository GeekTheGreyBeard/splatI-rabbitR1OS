#
# Copyright (C) 2021 The Android Open Source Project
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

# The system image of gsi_arm64-userdebug is the GSI for devices with:
# - ARM 64-bit userspace
# - 64-bit binder interface
# - system-as-root
# - VNDK enforcement
# - compatible property override enabled

# Skip WallpaperBackup. base_system.mk gates it behind
# `ifeq (,$(DISABLE_WALLPAPER_BACKUP))` (true → block runs). Make's ifeq is
# parse-time, so this MUST be set before the first inherit-product below.
# Saves the package and its system_server backup-agent classpath entry.
DISABLE_WALLPAPER_BACKUP := true

# Skip DynamicSystemInstallationService (DSU). base_system.mk gates it via
# `ifneq ($(PRODUCT_NO_DYNAMIC_SYSTEM_UPDATE),true)`. DSU is the GSI-side-load
# mechanism for testing alternate system images at runtime — useful for ROM
# devs, dead weight in a shipped kiosk. Same parse-time rule as above: set
# before the inherit chain.
PRODUCT_NO_DYNAMIC_SYSTEM_UPDATE := true

#
# All components inherited here go to system image
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system.mk)

#
# All components inherited here go to system_ext image
#
$(call inherit-product, device/generic/common/gsi_system_ext.mk)

#
# All components inherited here go to product image
#
$(call inherit-product, device/generic/common/gsi_product.mk)

#
# Special settings for GSI releasing
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)

# Inherit from r1 device
$(call inherit-product, device/rabbit/r1/device.mk)

# Lineage common product config. Required because Lineage's patched
# frameworks/base depends on:
#   - /system/framework/org.lineageos.platform-res.apk + .jar (from
#     lineage_sdk_common.mk, transitively included by common.mk)
#   - LineageSettingsProvider (the content provider behind
#     content://lineagesettings/...; without it, DisplayPolicy.updateSettings
#     hits a NullPointerException calling LineageSettings.System.getInt and
#     zygote dies → bootloop on Android logo)
#   - other Lineage system services that the patched frameworks expects
# We deliberately do NOT inherit common_mobile.mk to keep the image small for
# the R1 form factor.
$(call inherit-product, vendor/lineage/config/common.mk)

# GMS
$(call inherit-product-if-exists, vendor/google/gms/config.mk)

# Mark this as a Lineage build so the AOSP/GSI product .mks skip their own
# apns-conf.xml PRODUCT_COPY_FILES (Lineage's telephony.mk already adds it via
# PRODUCT_PACKAGES, otherwise we get a duplicate install-rule error).
LINEAGE_BUILD := r1

PRODUCT_NAME := gsi_r1
PRODUCT_DEVICE := r1
PRODUCT_BRAND := rabbit
PRODUCT_MODEL := Rabbit R1

# Slim Lineage userspace — drop bits that don't fit the R1 form factor.
# Jelly (browser), LineageParts (Settings UI extras), and LineageSetupWizard
# are dead weight on a device this small. LineageSettingsProvider stays because
# it's boot-critical (see common.mk inherit comment above).
PRODUCT_PACKAGES := $(filter-out Jelly LineageParts LineageSetupWizard,$(PRODUCT_PACKAGES))

# FMRadio JNI namespace — Lineage adds this via BoardConfigLineage.mk for non-MTK
# boards, but the R1 GSI tree doesn't include that file. R1 has no FM tuner, but
# the FMRadio app is pulled in by the Lineage system inheritance and must compile.
PRODUCT_SOONG_NAMESPACES += packages/apps/FMRadio/jni/fmr

# NOTE on status_bar_height_*: Lineage's vendor/lineage/overlay/no-rro/
# .../dimens.xml hard-pins these to 28dp and wins over our device overlay
# regardless of merge order. filter-out on PRODUCT_PACKAGE_OVERLAYS doesn't
# remove inherited entries (same product-namespacing trap as
# PRODUCT_PACKAGES). The actual fix lives in that file (edited in-tree to
# 0dp); see r1_kiosk_dimens.xml comment.
