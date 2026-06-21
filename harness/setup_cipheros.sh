#!/usr/bin/env bash
# setup_cipheros.sh — runs CipherOS R1 prep phases (STEPS 1-6).
# Stops BEFORE the final ROM build (STEP 7 / `mka bacon`) so you can
# inspect the source tree and bloat strip first.
#
# Run: ./setup_cipheros.sh
# Override paths via env: SOURCE_TREE=... ./setup_cipheros.sh

set -euo pipefail

# ---------- Config ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_TREE="${SOURCE_TREE:-$HOME/cipher}"
MANIFEST_URL="https://github.com/CipherOS/android_manifest"
# Android 15 base. Android 16 (sixteen-qpr2) does NOT work — the R1 maintainer
# (techyminati) only ships an Android 15 device tree / kernel / vendor blobs.
MANIFEST_BRANCH="fifteen"
DEVICE_BRANCH="fifteen"
KERNEL_BRANCH="alps-mp-t0.mp1.tc16sp-pr1-V1"
VENDOR_BRANCH="android-15"

# ---------- Helpers ----------
log()  { printf '\n\033[1;36m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\n\033[1;33m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
die()  { printf '\n\033[1;31m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }

# ---------- Pre-flight: fail fast before the 3-6h sync ----------
preflight() {
  log "PRE-FLIGHT  validating inputs before long-running steps"
  log "  retired custom launcher APK is intentionally not required"
}

# ---------- STEP 1: deps ----------
step1_deps() {
  log "STEP 1/6  installing build dependencies (sudo)"
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
  log "STEP 2/6  configuring git + ccache (50G)"

  # Only set a global git identity if one isn't already configured —
  # don't overwrite the user's real name/email.
  if ! git config --global --get user.email >/dev/null 2>&1; then
    log "  no global git identity found — setting placeholder for repo sync"
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

# ---------- STEP 3: repo init + sync (3-6h on first run) ----------
step3_repo_sync() {
  log "STEP 3/6  repo init + sync into $SOURCE_TREE  (3-6h on first run)"
  mkdir -p "$SOURCE_TREE"
  cd "$SOURCE_TREE"
  # Always run repo init — it's a no-op if the branch already matches and a
  # clean manifest swap if it doesn't (e.g. switching sixteen-qpr2 -> fifteen).
  repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH"
  repo sync -c -j4 --force-sync --no-clone-bundle --no-tags
}

# ---------- STEP 4: device tree, kernel, vendor blobs ----------
step4_device_trees() {
  log "STEP 4/6  cloning R1 device tree, kernel, vendor blobs"
  cd "$SOURCE_TREE"
  if [[ ! -d device/rabbit/r1 ]]; then
    git clone https://github.com/techyminati/android_device_rabbit_r1 \
      device/rabbit/r1 -b "$DEVICE_BRANCH"
  else log "  device/rabbit/r1 exists — skipping"; fi

  if [[ ! -d kernel/mediatek/alps-4.19 ]]; then
    git clone https://github.com/techyminati/alps-4.19 \
      kernel/mediatek/alps-4.19 -b "$KERNEL_BRANCH"
  else log "  kernel/mediatek/alps-4.19 exists — skipping"; fi

  if [[ ! -d vendor/rabbit/r1 ]]; then
    git clone https://github.com/techyminati/proprietary_vendor_rabbit_r1 \
      vendor/rabbit/r1 -b "$VENDOR_BRANCH"
  else log "  vendor/rabbit/r1 exists — skipping"; fi
}

# ---------- STEP 5: retired launcher cleanup ----------
step5_launcher() {
  log "STEP 5/6  retired custom launcher intentionally not installed"
  local dest="$SOURCE_TREE/device/rabbit/r1/prebuilt/app/R1Launcher"
  if [[ -e "$dest" ]]; then
    warn "  removing stale retired launcher prebuilt directory: $dest"
    rm -rf "$dest"
  fi
}

# ---------- STEP 6: strip bloat ----------
# Idempotent: only matches lines that aren't already commented (`#` not first
# non-whitespace char) AND aren't already prefixed with our `# REMOVED:` marker.
step6_strip_bloat() {
  log "STEP 6/6  stripping bloat apps from vendor/cipher configs"
  local mobile="$SOURCE_TREE/vendor/cipher/config/common_mobile.mk"
  local full="$SOURCE_TREE/vendor/cipher/config/common_full.mk"
  [[ -f "$mobile" ]] || die "common_mobile.mk missing at $mobile — did repo sync finish?"

  for pkg in Email Exchange2 Backgrounds Eleven Etar Jelly OmniStyle AudioFX \
             TrebuchetQuickStep TrebuchetQuickStepGo; do
    sed -i "/^[[:space:]]*#/! s/^\\(.*\\b$pkg\\b\\)/# REMOVED: \\1/" "$mobile"
  done

  if [[ -f "$full" ]]; then
    sed -i '/^[[:space:]]*#/! s/^\(.*\bRecorder\b\)/# REMOVED: \1/' "$full"
  else
    warn "  common_full.mk not found at $full — skipping Recorder removal"
  fi
}

# ---------- run ----------
preflight
step1_deps
step2_git_ccache
step3_repo_sync
step4_device_trees
step5_launcher
step6_strip_bloat

log "DONE — phases 1-6 complete."
log "Source tree:  $SOURCE_TREE"
log "Inspect, then run STEP 7 yourself when ready:"
cat <<'EOF'

    cd ~/cipher
    source build/envsetup.sh
    lunch cipher_r1-userdebug
    mka bacon -j6 2>&1 | tee build.log

EOF
