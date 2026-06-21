PRODUCT_COPY_FILES += \
    frameworks/av/media/libeffects/data/audio_effects.conf:system/etc/audio_effects.conf \
    frameworks/native/data/etc/android.hardware.location.gps.xml:system/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.sensor.barometer.xml:system/etc/permissions/android.hardware.sensor.barometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:system/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:system/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:system/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:system/etc/permissions/android.hardware.telephony.ims.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:system/etc/permissions/handheld_core_hardware.xml \
    $(LOCAL_PATH)/rootdir/system/etc/init/r1_kiosk.rc:system/etc/init/r1_kiosk.rc \
    $(LOCAL_PATH)/rootdir/system/etc/init/r1_side_button.rc:system/etc/init/r1_side_button.rc \
    $(LOCAL_PATH)/rootdir/system/bin/rabobster-side-button:system/bin/rabobster-side-button \
    device/sample/etc/apns-full-conf.xml:system/etc/apns-conf.xml

# Keylayout
# Side button: remap KEY_POWER (116) to BUTTON_1 so the device can handle
# wake/lock/PTT behavior without forcing the retired custom launcher into the
# image. BUTTON_1 has no framework handling, so downstream handlers can observe
# raw DOWN/UP timing without PhoneWindowManager consuming the event as POWER.
# A name-specific .kl in /system/usr/keylayout/ wins over Generic.kl during EventHub
# search, so this overrides the stock POWER mapping without editing Generic.kl.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/keylayout/mtk-kpd.kl:$(TARGET_COPY_OUT_SYSTEM)/usr/keylayout/mtk-kpd.kl

#PRODUCT_COPY_FILES += \
#    $(LOCAL_PATH)/keylayout/och1970_holl_key.kl:$(TARGET_COPY_OUT_PRODUCT)/usr/keylayout/och1970_holl_key.kl

# A/B
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)
AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

PRODUCT_PACKAGES += \
    otapreopt_script \
    cppreopts.sh

# Bootctrl
PRODUCT_PACKAGES += \
    android.hardware.boot@1.1 \
    android.hardware.boot@1.1-service

PRODUCT_PROPERTY_OVERRIDES += \
    ro.cp_system_other_odex=1 \
    qemu.hw.mainkeys=1 \
    ro.setupwizard.mode=DISABLED \
    bluetooth.profile.a2dp.source.enabled=true \
    bluetooth.profile.hfp.ag.enabled=true \
    bluetooth.profile.avrcp.target.enabled=true

# Bluetooth Audio HAL (AIDL). Without this, android.hardware.bluetooth.audio
# is declared in the VINTF but no service instantiates it — A2DP/HFP "connect"
# at the protocol level but audio frames have no path to the BT chip, so TTS
# and mic input fall back to the built-in speaker/mic.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth.audio-impl

PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier

PRODUCT_PACKAGES_DEBUG += \
    update_engine_client

# Ims
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/permissions/privapp-permissions-mtkimsservice.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/privapp-permissions-mtkimsservice.xml

SKIP_BOOT_JARS_CHECK := true

PRODUCT_BOOT_JARS += \
    mediatek-common \
    mediatek-framework \
    mediatek-ims-base \
    mediatek-ims-common \
    mediatek-telecom-common \
    mediatek-telephony-base \
    mediatek-telephony-common

# Keyhandler
PRODUCT_PACKAGES += \
    KeyHandler

# Step Motor
PRODUCT_PACKAGES += \
    StepMotorControls

# Overlays
PRODUCT_ENFORCE_RRO_EXCLUDED_OVERLAYS := device/rabbit/r1
DEVICE_PACKAGE_OVERLAYS += \
    device/rabbit/r1/overlay

# Inherit the proprietary files
$(call inherit-product, vendor/rabbit/r1/r1-vendor.mk)
