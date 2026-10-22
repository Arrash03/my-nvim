#!/usr/bin/env bash
# Build the proot 5.4.0 binary used by the sandbox scripts.
#
# This is a HOST build tool only -- it is never shipped inside the .deb.
# The proot source is vendored under tools/proot-5.4.0; the binary lands at
# tools/proot-5.4.0/src/proot (see scripts/lib.sh: $PROOT).
#
# proot links against talloc:
#   * if the system provides libtalloc-dev (pkg-config talloc) we use it;
#   * otherwise we fall back to the vendored talloc extracted from Ubuntu
#     debs under tools/debs/usr (with an rpath so the binary finds
#     libtalloc.so.2 at runtime without LD_LIBRARY_PATH).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/tools/proot-5.4.0"
PROOT_BIN="$SRC/src/proot"

if [[ -x "$PROOT_BIN" ]]; then
  echo "[nvf] proot already built: $PROOT_BIN"
  exit 0
fi

if pkg-config --exists talloc 2>/dev/null; then
  echo "[nvf] building proot against system talloc ($(pkg-config --modversion talloc))"
  make -C "$SRC/src" -j"$(nproc)"
else
  echo "[nvf] system talloc not found; building proot against vendored tools/debs talloc"
  DEB="$ROOT/tools/debs/usr"
  LIBDIR="$DEB/lib/x86_64-linux-gnu"
  [[ -f "$DEB/include/talloc.h" && -f "$LIBDIR/libtalloc.so" ]] \
    || { echo "[nvf] vendored talloc missing under tools/debs" >&2; exit 1; }
  # The proot makefile hardcodes `pkg-config`; shadow it with a shim that
  # emits the vendored include/lib/rpath flags.
  SHIM="$(mktemp -d)"
  trap 'rm -rf "$SHIM"' EXIT
  cat > "$SHIM/pkg-config" <<EOF
#!/bin/sh
echo "-I$DEB/include -L$LIBDIR -Wl,-rpath,$LIBDIR -ltalloc"
EOF
  chmod +x "$SHIM/pkg-config"
  PATH="$SHIM:$PATH" make -C "$SRC/src" -j"$(nproc)"
fi

[[ -x "$PROOT_BIN" ]] || { echo "[nvf] proot build failed" >&2; exit 1; }
echo "[nvf] built $PROOT_BIN ($("$PROOT_BIN" --version 2>/dev/null | head -1 || echo 'version check n/a'))"
