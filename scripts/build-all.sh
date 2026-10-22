#!/usr/bin/env bash
# One-shot build: fetch -> sandbox -> parsers -> stage -> ELF audit ->
# package -> offline acceptance suite.
#
#   bash scripts/build-all.sh
#
# Produces:
#   dist/nvim-forge_<version>_amd64.deb
#   dist/SHA256SUMS
#   dist/TEST-REPORT.md
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

step() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$*" >&2; }

step "1/7 fetch + verify pinned artifacts"
bash scripts/fetch.sh

step "2/7 prepare Ubuntu 22.04 sandboxes (build + test rootfs)"
bash scripts/sandbox.sh

step "3/7 compile Tree-sitter parsers in the 22.04 sandbox"
bash scripts/build-parsers.sh

step "4/7 stage /opt/nvim-forge tree"
bash scripts/stage.sh

step "5/7 audit shared libraries and glibc/GLIBCXX ceilings"
bash scripts/check-elf.sh

step "6/7 build the .deb"
bash scripts/build-deb.sh

step "7/7 offline acceptance suite"
bash scripts/verify.sh

printf '\n\033[1;32mBuild + test complete.\033[0m See dist/ for the package, checksums and test report.\n' >&2
