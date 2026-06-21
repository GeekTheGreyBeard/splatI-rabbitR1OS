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
# Safety knobs:
#   DRY_RUN=1      print risky commands instead of running them
#   ASSUME_YES=1   skip confirmation prompts

set -euo pipefail

# ---------- Config ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_TREE="${SOURCE_TREE:-$HOME/lineage}"
BASHRC_PATH="${BASHRC_PATH:-$HOME/.bashrc}"
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
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

confirm() {
  local prompt="$1" reply
  if [[ "$ASSUME_YES" == "1" ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^([yY]|[yY][eE][sS])$ ]]
}

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY_RUN:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_safe_source_tree() {
  [[ -n "$SOURCE_TREE" ]] || die "SOURCE_TREE is empty"
  [[ "$SOURCE_TREE" != "/" ]] || die "Refusing to use SOURCE_TREE=/"
  [[ "$SOURCE_TREE" != "$HOME" ]] || die "Refusing to use SOURCE_TREE=$HOME"
}

append_bashrc_once() {
  local line="$1"
  if grep -qxF "$line" "$BASHRC_PATH" 2>/dev/null; then
    return
  fi
  if confirm "Append '$line' to $BASHRC_PATH?"; then
    if [[ "$DRY_RUN" == "1" ]]; then
      printf 'DRY_RUN: append %q to %q\n' "$line" "$BASHRC_PATH"
    else
      printf '%s\n' "$line" >> "$BASHRC_PATH"
    fi
  else
    warn "  skipped $BASHRC_PATH update for: $line"
  fi
}

# ---------- Pre-flight ----------
preflight() {
  log "PRE-FLIGHT  validating inputs before long-running steps"
  require_safe_source_tree
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
  if ! confirm "Run sudo apt update/install on this host?"; then
    warn "  skipped dependency install"
    return
  fi
  run_cmd sudo apt update
  run_cmd sudo apt install -y \
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
    if confirm "No global git identity found. Set placeholder identity globally for repo sync?"; then
      log "  setting placeholder global git identity for repo sync"
      run_cmd git config --global user.name  "R1 Builder"
      run_cmd git config --global user.email "r1builder@localhost"
    else
      warn "  skipped global git identity fallback"
    fi
  else
    log "  keeping existing global git identity: $(git config --global user.email)"
  fi

  export USE_CCACHE=1
  export CCACHE_EXEC=/usr/bin/ccache
  run_cmd ccache -M 50G
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY_RUN: ensure %q exists\n' "$BASHRC_PATH"
  else
    touch "$BASHRC_PATH"
  fi
  append_bashrc_once 'export USE_CCACHE=1'
  append_bashrc_once 'export CCACHE_EXEC=/usr/bin/ccache'
}

# ---------- STEP 3: repo init + sync ----------
step3_repo_sync() {
  log "STEP 3/5  repo init + sync into $SOURCE_TREE  (3-5h on first run)"
  require_safe_source_tree
  run_cmd mkdir -p "$SOURCE_TREE"
  if [[ "$DRY_RUN" != "1" ]]; then
    cd "$SOURCE_TREE"
  fi
  run_cmd repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --git-lfs
  if confirm "Run repo sync --force-sync in $SOURCE_TREE? This can overwrite local repo checkout edits."; then
    run_cmd repo sync -c -j4 --force-sync --no-clone-bundle --no-tags
  else
    warn "  skipped repo sync --force-sync"
  fi
}

# ---------- STEP 4: device tree, vendor blobs, kernel ----------
step4_device_trees() {
  log "STEP 4/5  cloning R1 GSI device tree, vendor blobs, kernel"
  local device_path="$SOURCE_TREE/device/rabbit/r1"
  local vendor_path="$SOURCE_TREE/vendor/rabbit/r1"
  local kernel_path="$SOURCE_TREE/kernel/mediatek/alps-4.19"

  if [[ ! -d "$device_path" ]]; then
    run_cmd git clone "$DEVICE_REPO" "$device_path" -b "$DEVICE_BRANCH"
  else
    log "  device/rabbit/r1 exists — skipping"
  fi

  if [[ ! -d "$vendor_path" ]]; then
    run_cmd git clone "$VENDOR_REPO" "$vendor_path" -b "$VENDOR_BRANCH"
  else
    log "  vendor/rabbit/r1 exists — skipping"
  fi

  if [[ ! -d "$kernel_path" ]]; then
    run_cmd git clone "$KERNEL_REPO" "$kernel_path" -b "$KERNEL_BRANCH"
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
    case "$dest" in
      "$SOURCE_TREE"/device/rabbit/r1/prebuilt/app/R1Launcher)
        if confirm "Remove stale launcher directory $dest?"; then
          run_cmd rm -rf "$dest"
        else
          warn "  kept stale launcher directory"
        fi
        ;;
      *) die "Refusing rm -rf outside expected SOURCE_TREE path: $dest" ;;
    esac
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
