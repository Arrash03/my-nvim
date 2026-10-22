#!/usr/bin/env bash
# Build the Tree-sitter parsers for python, c, cpp and rust.
#
# Grammar sources are pinned in manifest/pins.json to the exact revisions
# required by the vendored nvim-treesitter plugin (parsers.lua), so the
# bundled queries always match the parsers.
#
# Compilation happens inside the Ubuntu 22.04 sandbox with its gcc, which
# guarantees the resulting .so files only use the 22.04 ABI.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OUT="$BUILD_DIR/parsers/parser"
mkdir -p "$OUT" "$BUILD_DIR/.work"

build_one() { # $1=archive $2=lang $3=strip-components
  local archive="$1" lang="$2" strip="$3"
  local work="$BUILD_DIR/.work/ts-$lang"
  rm -rf "$work"; mkdir -p "$work"
  tar xzf "$archive" -C "$work" --strip-components="$strip"

  # Compile every C source in src/ (parser.c + optional scanners) inside the
  # sandbox; the build directory is mounted at /nvf-build there.
  local work_sbx="/nvf-build/.work/ts-$lang"
  log "compiling $lang parser inside the 22.04 sandbox"
  run22 "$ROOTFS_BUILD" /bin/bash -c "
    set -e
    cd '$work_sbx'
    mapfile -t srcs < <(find src -name '*.c' | sort)
    [ \${#srcs[@]} -gt 0 ] || { echo 'no sources'; exit 1; }
    gcc -O2 -fPIC -shared -I src -o /nvf-build/parsers/parser/$lang.so \"\${srcs[@]}\" 2>/tmp/gcc.err || { cat /tmp/gcc.err; exit 1; }
    strip --strip-unneeded /nvf-build/parsers/parser/$lang.so
  "
  [[ -s "$OUT/$lang.so" ]] || die "$lang: parser not produced"
}

build_one "$DL_DIR/v0.25.0.tar.gz"                                python 1
build_one "$DL_DIR/b780e47fc780ddc8da13afa35a3f4ed5c157823d.tar.gz" c     1
build_one "$DL_DIR/c009222808634c1014f82438d4883753516a2c24.tar.gz" cpp   1
build_one "$DL_DIR/77a3747266f4d621d0757825e6b11edcbf991ca5.tar.gz" rust  1

log "parsers built:"
ls -la "$OUT"
