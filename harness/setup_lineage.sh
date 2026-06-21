#!/usr/bin/env bash
# setup_lineage.sh — runs LineageOS 21 GSI prep phases for the Rabbit R1.
# Mirrors setup_cipheros.sh but targets LineageOS 21 (Android 14) + the
# RabbitHoleEscapeR1 GSI device tree.
#
# Stops BEFORE the final ROM build (`mka bacon` / `mka systemimage`) so you
# can inspect the source tree first.
#
# Run: ./setup_lineage.sh
# Override paths via env: SOURCE_TREE=... ./setup_lineage.sh

set -euo pipefail

# ---------- Config ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_TREE="${SOURCE_TREE:-$HOME/lineage}"
# LineageOS 21 = Android 14. The R1 has no proper device tree on Lineage —
# only a GSI tree from RabbitHoleEscapeR1. We ride on that and ship a
# generic-system-image build.
MANIFEST_URL="https://github.com/LineageOS/android.git"
MANIFEST_BRANCH="lineage-21.0"

# Device tree, vendor blobs — both from RabbitHoleEscapeR1 (default branch: main).
DEVICE_REPO="https://github.com/RabbitHoleEscapeR1/device_rabbit_r1"
DEVICE_BRANCH="main"
VENDOR_REPO="https://github.com/RabbitHoleEscapeR1/vendor_rabbit_r1"
VENDOR_BRANCH="main"

# Kernel: same MediaTek alps-4.19 as before. Hardware-specific, not Android-version-specific.
KERNEL_REPO="https://github.com/techyminati/alps-4.19"
KERNEL_BRANCH="alps-mp-t0.mp1.tc16sp-pr1-V1"

# ---------- Helpers ----------
log()  { printf '\n\033[1;36m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\n\033[1;33m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
die()  { printf '\n\033[1;31m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }

# ---------- Pre-flight ----------
preflight() {
  log "PRE-FLIGHT  validating inputs before long-running steps"
  log "  retired custom launcher APK is intentionally not required"

  # Fail early if disk is tight. Lineage 21 sync + build needs ~250GB free.
  local avail_kb
  avail_kb="$(df -k "$HOME" | awk 'NR==2 {print $4}')"
  if (( avail_kb < 250 * 1024 * 1024 )); then
    warn "Free space on \$HOME is $((avail_kb / 1024 / 1024))GB — recommended ≥250GB."
  fi
}

# ---------- STEP 1: deps ----------
step1_deps() {
  log "STEP 1/5  installing build dependencies (sudo)"
  # Lineage 21 uses JDK 17 for build, same as recent CipherOS branches.
  sudo apt update
  sudo apt install -y \
    bc bison build-essential ccache curl flex \
    g++-multilib gcc-multilib git git-lfs gnupg \
    gperf imagemagick lib32readline-dev lib32z1-dev \
    libelf-dev liblz4-tool libsdl1.2-dev libssl-dev \
    libxml2 libxml2-utils lzop pngcrush rsync \
    schedtool squashfs-tools xsltproc zip zlib1g-dev \
    python3 python3-pip openjdk-17-jdk \
    libncurses-dev repo fontconfig \
    python-is-python3 wget unzip
}

# ---------- STEP 2: git + ccache ----------
step2_git_ccache() {
  log "STEP 2/5  configuring git + ccache (50G)"
  if ! git config --global --get user.email >/dev/null 2>&1; then
    log "  no global git identity — setting placeholder"
    git config --global user.name  "R1 Builder"
    git config --global user.email "r1builder@localhost"
  else
    log "  keeping existing global git identity: $(git config --global user.email)"
  fi

  export USE_CCACHE=1
  export CCACHE_EXEC=/usr/bin/ccache
  ccache -M 50G
  touch ~/.bashrc
  grep -q 'USE_CCACHE=1'                ~/.bashrc 2>/dev/null || echo 'export USE_CCACHE=1'                >> ~/.bashrc
  grep -q 'CCACHE_EXEC=/usr/bin/ccache' ~/.bashrc 2>/dev/null || echo 'export CCACHE_EXEC=/usr/bin/ccache' >> ~/.bashrc
}

# ---------- STEP 3: repo init + sync ----------
step3_repo_sync() {
  log "STEP 3/5  repo init + sync into $SOURCE_TREE  (3-5h on first run)"
  mkdir -p "$SOURCE_TREE"
  cd "$SOURCE_TREE"
  repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --git-lfs
  repo sync -c -j4 --force-sync --no-clone-bundle --no-tags
}

# ---------- STEP 4: device tree, vendor blobs, kernel ----------
step4_device_trees() {
  log "STEP 4/5  cloning R1 GSI device tree, vendor blobs, kernel"
  cd "$SOURCE_TREE"

  if [[ ! -d device/rabbit/r1 ]]; then
    git clone "$DEVICE_REPO" device/rabbit/r1 -b "$DEVICE_BRANCH"
  else
    log "  device/rabbit/r1 exists — skipping"
  fi

  if [[ ! -d vendor/rabbit/r1 ]]; then
    git clone "$VENDOR_REPO" vendor/rabbit/r1 -b "$VENDOR_BRANCH"
  else
    log "  vendor/rabbit/r1 exists — skipping"
  fi

  if [[ ! -d kernel/mediatek/alps-4.19 ]]; then
    git clone "$KERNEL_REPO" kernel/mediatek/alps-4.19 -b "$KERNEL_BRANCH"
  else
    log "  kernel/mediatek/alps-4.19 exists — skipping"
  fi
}

# ---------- STEP 5: retired launcher cleanup ----------
step5_launcher() {
  log "STEP 5/5  retired custom launcher intentionally not installed"
  local dest="$SOURCE_TREE/device/rabbit/r1/prebuilt/app/R1Launcher"
  if [[ -e "$dest" ]]; then
    warn "  removing stale retired launcher prebuilt directory: $dest"
    rm -rf "$dest"
  fi
}

# ---------- run ----------
preflight
step1_deps
step2_git_ccache
step3_repo_sync
step4_device_trees
step5_launcher

log "DONE — phases 1-5 complete."
log "Source tree:  $SOURCE_TREE"
cat <<'EOF'

Next: figure out the lunch target by listing device products, then build:

    cd ~/lineage
    source build/envsetup.sh
    lunch          # interactive — pick the *_r1 entry (likely lineage_gsi_r1-userdebug)
    mka systemimage -j6 2>&1 | tee build.log

Output GSI: ~/lineage/out/target/product/<product>/system.img
Flash via fastboot:
    fastboot flash system system.img
    fastboot flash --disable-verity --disable-verification vbmeta /path/to/vbmeta.img

EOF
