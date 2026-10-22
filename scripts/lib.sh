# shellcheck shell=bash
# Common helpers for nvim-forge build scripts.
set -euo pipefail

NVF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NVF_ROOT

CACHE_DIR="$NVF_ROOT/cache"
DL_DIR="$CACHE_DIR/downloads"
TOOLS_DIR="$NVF_ROOT/tools"
SANDBOX_DIR="$NVF_ROOT/sandbox"
ROOTFS_BUILD="$SANDBOX_DIR/rootfs-build"
ROOTFS_TEST="$SANDBOX_DIR/rootfs-test"
BUILD_DIR="$NVF_ROOT/build"
STAGE_DIR="$BUILD_DIR/root"
DIST_DIR="$NVF_ROOT/dist"
MANIFEST_DIR="$NVF_ROOT/manifest"

PINS_FILE="$MANIFEST_DIR/pins.json"
LOCKS_FILE="$MANIFEST_DIR/pins-locked.json"

log()  { printf '\033[1;34m[nvf]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[nvf]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[nvf]\033[0m FATAL: %s\n' "$*" >&2; exit 1; }

sha256_of() { sha256sum "$1" | awk '{print $1}'; }

# PRoot sandbox runner.  Usage: run22 <rootfs> <cmd...>
# --root-id fakes uid 0 (needed by dpkg/apt).
# NOTE: deliberately NOT using -R (recommended bindings) because -R bind
# mounts the *host* /etc/passwd and /etc/group into the guest; we want
# package operations to touch only the guest rootfs.  /etc/resolv.conf is
# copied into the rootfs by sandbox.sh instead.
PROOT="$TOOLS_DIR/proot-5.4.0/src/proot"
run22() {
  local rootfs="$1"; shift
  "$PROOT" --root-id -r "$rootfs" -b /proc -b /dev -b /sys \
    -b "$NVF_ROOT/build:/nvf-build" -b "$DIST_DIR:/nvf-dist" -w /root "$@"
}

# Same, but without faking root (plain user execution).
run22_user() {
  local rootfs="$1"; shift
  "$PROOT" -r "$rootfs" -b /proc -b /dev -b /sys \
    -b "$NVF_ROOT/build:/nvf-build" -b "$DIST_DIR:/nvf-dist" -w /root "$@"
}

# jq helpers -------------------------------------------------------------
jqv() { jq -r "$1" "$PINS_FILE"; }

# Effective pinned hash: pins-locked.json wins over pins.json (null hashes).
effective_sha() {  # $1 = artifact name
  local h
  h=$(jq -r --arg n "$1" '.[$n].sha256 // empty' "$LOCKS_FILE" 2>/dev/null || true)
  if [[ -z "$h" ]]; then
    h=$(jqv ".artifacts[\"$1\"].sha256 // empty")
  fi
  printf '%s' "$h"
}
