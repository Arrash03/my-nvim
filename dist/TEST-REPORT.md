# nvim-forge offline test report

- Package: `nvim-forge_1.0.0_amd64.deb` (287M, installed 1203020 KiB)
- Built: 2026-10-22 11:09:51 UTC
- Target: Ubuntu 22.04 (amd64), glibc baseline 2.35 (Ubuntu 22.04)
- Environment: proot 5.4.0 sandbox on a pristine ubuntu-base-22.04.5
  rootfs (used instead of Docker/Podman: neither is available on the
  build host and unprivileged user namespaces are blocked by AppArmor).
- Result: **15 passed, 0 failed**

| ID | Check | Result |
|----|-------|--------|
| T01 | SHA256SUMS verified; metadata ok (sha256=0fb7380fe7e82974…) | PASS |
| T02 | clean dpkg -i install; system /usr/bin/nvim untouched | PASS |
| T03 | nvim-forge --version -> NVIM v0.12.6 | PASS |
| T04 | headless startup: theme, options, plugins, LSP config, exes | PASS |
| T05 | Tree-sitter parses python/c/cpp/rust; highlighter attaches | PASS |
| T06 | LSP attach: basedpyright (test.py) | PASS |
| T07 | LSP attach: clangd (test.c) | PASS |
| T08 | LSP attach: clangd (test.cpp) | PASS |
| T09 | LSP attach: rust_analyzer (test.rs) | PASS |
| T10 | ldd over installed bundle: ELF-scanned=41, all resolve | PASS |
| T11 | non-root (uid 1000) startup OK; 2 XDG state dir(s) created | PASS |
| T12 | bundle read-only (write probe refused) and editor still starts | PASS |
| T13 | offline: startup + 3 LSP servers with sockets blocked; strace saw 0 AF_INET* syscalls in 9 net syscalls | PASS |
| T14 | no hardcoded /home paths in config or launcher | PASS |
| T15 | dpkg -r removes bundle + launcher; system nvim and user state kept | PASS |

- Package SHA-256: `0fb7380fe7e82974de5ba77e4a452239f5462dd3edb168ae29cba1bf3f034de2`

## Versions under test

| Component | Version |
|-----------|---------|
| Neovim | 0.12.6 |
| BasedPyright | 1.40.2 |
| Node.js | 24.22.0 |
| clangd | 23.1.0 |
| Rust toolchain (rustc/cargo/rust-analyzer) | 1.99.1 |
| Tree-sitter parsers | python v0.25.0, c b780e47f, cpp c0092228, rust 77a37472 |
| Plugins | commit-pinned, see /opt/nvim-forge/manifest/pins.json |

## Limitations

- amd64 only; requires glibc >= 2.35 (Ubuntu 22.04+).
- Tree-sitter parsers ship for python, c, cpp and rust only.
- Validation ran inside a proot-based Ubuntu 22.04 rootfs rather than
  Docker/Podman (unavailable on the build host; AppArmor blocks
  unprivileged user namespaces), so kernel-level container isolation
  was not exercised - package installation, file layout, offline
  behaviour and removal were.
- Network independence was enforced with an LD_PRELOAD socket blocker
  and an independent strace audit, not with a network namespace.
