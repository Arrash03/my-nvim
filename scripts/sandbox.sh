#!/usr/bin/env bash
# Prepare the Ubuntu 22.04 rootfs sandboxes used for building and testing.
#
#   rootfs-build : + gcc/libc6-dev/make  -> compiles Tree-sitter parsers and
#                  the netguard test library against the 22.04 ABI.
#   rootfs-test  : pristine ubuntu-base  + strace (test infrastructure only)
#                  + a non-root 'tester' user.  This is the environment the
#                  .deb install/acceptance tests run in.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

prepare() { # $1=rootfs dir  $2=mode(build|test)
  local rootfs="$1" mode="$2"
  if [[ ! -d "$rootfs" ]]; then
    log "extracting ubuntu-base rootfs -> $rootfs"
    mkdir -p "$rootfs"
    tar -C "$rootfs" -xzf "$DL_DIR/ubuntu-base-22.04.5-base-amd64.tar.gz"
  fi
  # DNS inside the sandbox (network is available at build time).
  cp /etc/resolv.conf "$rootfs/etc/resolv.conf"

  if [[ ! -f "$rootfs/.nvf-prepared-$mode" ]]; then
    log "installing packages into $mode rootfs"
    run22 "$rootfs" /bin/bash -c '
      set -e
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      if [ "'"$mode"'" = build ]; then
        apt-get install -y -qq --no-install-recommends gcc libc6-dev make libc-bin
      fi
      apt-get install -y -qq --no-install-recommends strace
      apt-get clean
      rm -rf /var/lib/apt/lists/*
    '
    touch "$rootfs/.nvf-prepared-$mode"
  fi

  if [[ "$mode" == test && ! -f "$rootfs/.nvf-user-created" ]]; then
    log "creating non-root test user in $mode rootfs"
    run22 "$rootfs" /bin/bash -c '
      set -e
      useradd -m -u 1000 -s /bin/bash tester
      mkdir -p /home/tester/.cache /home/tester/.config /home/tester/.local
      chown -R tester:tester /home/tester
    '
    touch "$rootfs/.nvf-user-created"
  fi
}

prepare "$ROOTFS_BUILD" build
prepare "$ROOTFS_TEST" test
log "sandboxes ready: $ROOTFS_BUILD , $ROOTFS_TEST"
