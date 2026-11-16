#!/usr/bin/env bash
# Install the locally built package on this machine and sanity-check it.
#
#   sudo bash scripts/install-local.sh
#
# Verifies the .deb against dist/SHA256SUMS, installs it with dpkg and
# prints the bundled Neovim version.  Your existing /usr/bin/nvim and your
# per-user state (~/.local/state/nvim-forge, ...) are not touched.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEB="$ROOT/dist/nvim-forge_1.0.0_amd64.deb"

[[ -f "$DEB" ]] || { echo "missing $DEB -- run scripts/build-deb.sh first" >&2; exit 1; }

echo "==> verifying checksum"
(cd "$ROOT/dist" && sha256sum -c SHA256SUMS)

echo "==> installing $DEB"
dpkg -i "$DEB"

echo
echo "==> installed version: $(dpkg-query -W -f='${Version}' nvim-forge)"
"/usr/bin/nvim-forge" --version | head -1
echo
echo "Launch it with: nvim-forge [file]"
echo "The file explorer opens automatically (toggle: Space+e, disable: NVF_NO_TREE=1)."
