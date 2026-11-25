#!/usr/bin/env bash
# Build dist/nvim-forge_<version>_amd64.deb from the staged tree.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# NVF_VERSION wins over the manifest so CI can build a caller-supplied version
# (workflow_dispatch input or a `v<version>` git tag).
VERSION=${NVF_VERSION:-$(jqv '.version // empty')}
VERSION=${VERSION:-1.0.0}

DEBIAN="$STAGE_DIR/root/DEBIAN"
mkdir -p "$DEBIAN"

# Installed size in KiB.
installed_size=$(du -sk "$STAGE_DIR/root/opt" "$STAGE_DIR/root/usr" | awk '{s+=$1} END {print s}')

# Generate control from the template.
sed -e "s/^Version:.*/Version: $VERSION/" \
    -e "s/^Installed-Size:.*/Installed-Size: $installed_size/" \
    "$NVF_ROOT/packaging/control.in" > "$DEBIAN/control"
if ! grep -q '^Installed-Size:' "$DEBIAN/control"; then
  echo "Installed-Size: $installed_size" >> "$DEBIAN/control"
fi

# md5sums for all installed files.
( cd "$STAGE_DIR/root" && find opt usr etc -type f -print0 | xargs -0 md5sum ) > "$DEBIAN/md5sums"

# Maintainer scripts: only a guarded `fc-cache -f` (see packaging/postinst)
# so the bundled Nerd Font symbols are picked up immediately.  No network
# access and no other system-wide configuration changes.
for script in postinst postrm; do
  if [[ -f "$NVF_ROOT/packaging/$script" ]]; then
    install -m 0755 "$NVF_ROOT/packaging/$script" "$DEBIAN/$script"
  fi
done

log "building .deb (xz compression)"
mkdir -p "$DIST_DIR"
OUT="$DIST_DIR/nvim-forge_${VERSION}_amd64.deb"
dpkg-deb --build --root-owner-group -Zxz "$STAGE_DIR/root" "$OUT" >/dev/null

log "validating package metadata"
dpkg-deb -I "$OUT" | sed 's/^/    /'
dpkg-deb -c "$OUT" >/dev/null || die "package contents unreadable"

( cd "$DIST_DIR" && sha256sum "nvim-forge_${VERSION}_amd64.deb" > SHA256SUMS )
log "wrote $OUT ($(du -h "$OUT" | cut -f1)) and $DIST_DIR/SHA256SUMS"
