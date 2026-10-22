# nvim-forge — project report (2026-10-20)

Everything about the finished build in one place: what was produced, how to
use it, how to rebuild it, what was tested, and what the caveats are.

## 1. What was built

A complete, self-contained, **offline** Neovim distribution for Ubuntu
22.04+ (amd64), packaged as a single `.deb`.

- Installs under `/opt/nvim-forge/`, launcher at `/usr/bin/nvim-forge`.
- Never touches the system Neovim (`/usr/bin/nvim` is left alone — verified
  by test T02 with a planted fake system nvim).
- After `sudo dpkg -i` the whole stack works with **no network at all**:
  no plugin downloads, no Mason, no npm/rustup/git/compiler on the target.

## 2. Artifacts

| File | Size | Notes |
|---|---|---|
| `dist/nvim-forge_1.0.0_amd64.deb` | 287 MB | ~1.17 GB installed |
| `dist/SHA256SUMS` | — | checksum of the .deb |
| `dist/TEST-REPORT.md` | — | offline acceptance results |

SHA-256 of the .deb:
`0fb7380fe7e82974de5ba77e4a452239f5462dd3edb168ae29cba1bf3f034de2`

Package metadata: `Depends: libc6 (>= 2.35), libgcc-s1, libstdc++6`,
`Architecture: amd64`, no maintainer scripts (install makes no system
changes, needs no network).

## 3. Bundled versions

| Component | Version |
|---|---|
| Neovim | 0.12.6 (official x86_64 build) |
| Node.js runtime | 24.22.0 (binary only; no npm/npx/corepack) |
| BasedPyright | 1.40.2 (Python LSP, runs on bundled node) |
| clangd | 23.1.0 (C/C++) |
| Rust toolchain | 1.99.1 (rustc, cargo, rust-std, rust-src) |
| rust-analyzer | 1.99.1 (+ proc-macro server inside rustc) |
| Tree-sitter parsers | python v0.25.0, c b780e47f, cpp c0092228, rust 77a37472 |
| Plugins | 13, commit-pinned (nvim-treesitter, nvim-lspconfig, nvim-cmp, cmp-nvim-lsp, cmp-buffer, LuaSnip, friendly-snippets, lualine.nvim, nvim-autopairs, telescope.nvim, plenary.nvim, nvim-tree.lua + nvim-web-devicons) |
| Theme | custom "forge" (Kanagawa Dragon-derived, bg ≈ #0D0F12) |

All pins live in `manifest/pins.json` + `manifest/pins-locked.json`
(SHA-256 self-pinned; Node/Rust additionally verified against upstream
checksum files at fetch time). License texts of all 21 components ship in
`/opt/nvim-forge/licenses/`.

## 4. Use / uninstall

```sh
sudo dpkg -i nvim-forge_1.0.0_amd64.deb   # install
nvim-forge [file]                          # launch (Space = leader)
sudo dpkg -r nvim-forge                    # remove (user state kept)
```

Keymaps and full usage: `docs/CHEATSHEET.md` (also in the repo).
User state goes to `~/.local/state/nvim-forge`, `~/.cache/nvim-forge`,
`~/.local/share/nvim-forge` — the bundle is read-only at runtime.

## 5. Rebuild from source

```sh
bash scripts/build-all.sh    # one shot: fetch → sandbox → parsers →
                             # stage → ELF audit → .deb → test suite
```

Individual steps: `fetch.sh` (download+verify pins) → `sandbox.sh`
(prepare Ubuntu 22.04 proot rootfses) → `build-parsers.sh` (compile
grammars inside the 22.04 sandbox) → `stage.sh` (assemble /opt tree) →
`check-elf.sh` (ldd + glibc ceilings) → `build-deb.sh` → `verify.sh`
(15-check offline acceptance suite, writes `dist/TEST-REPORT.md`).

## 6. Test results — 15/15 PASS

Run in a pristine ubuntu-base-22.04.5 rootfs (see §8 for why proot):

| ID | Check |
|---|---|
| T01 | SHA256SUMS + package metadata |
| T02 | clean `dpkg -i`; system `/usr/bin/nvim` untouched |
| T03 | `nvim-forge --version` → NVIM v0.12.6 |
| T04 | headless startup: theme, options, plugins, LSP config, exes |
| T05 | Tree-sitter parses python/c/cpp/rust; highlighter attaches |
| T06–T09 | LSP attach: basedpyright, clangd (c), clangd (cpp), rust_analyzer |
| T10 | ldd over all 41 installed ELF files — nothing unresolved |
| T11 | runs as non-root uid 1000, XDG state created |
| T12 | bundle read-only (write probe refused), editor still starts |
| T13 | fully offline: startup + all 3 servers with sockets blocked; strace saw 0 AF_INET syscalls |
| T14 | no hardcoded `/home` paths in config/launcher |
| T15 | `dpkg -r` removes bundle+launcher; system nvim and user state kept |

ELF audit ceilings: max `GLIBC_2.34`, max `GLIBCXX_3.4.21` — inside the
Ubuntu 22.04 baseline (2.35 / 3.4.30). glibc/libstdc++ are never bundled;
they come from the declared `Depends`.

## 7. Known gaps / follow-ups

- **Python venv auto-detection is NOT implemented yet** (README claims it):
  BasedPyright runs with default sys.path. A small addition to
  `config/lua/forge/lsp.lua` (look for `.venv`/`venv` under the project
  root, put its `bin` on the server's `cmd_env.PATH`) would fix it —
  then re-run `scripts/build-all.sh` (~10 min).
- amd64 only; glibc ≥ 2.35 (Ubuntu 22.04+).
- Tree-sitter parsers ship for python/c/cpp/rust only.
- No new LSP servers/parsers at runtime by design (offline): rebuild needed.

## 8. Environment notes (useful if repeating this work)

- Build host: Ubuntu 24.04, **no Docker/Podman**, and AppArmor blocks
  unprivileged user namespaces (`kernel.apparmor_restrict_unprivileged_userns=1`)
  → used **proot 5.4.0** (built from source) with ubuntu-base-22.04.5 rootfs.
- proot gotchas learned:
  - use `--root-id` (not `-0`, which breaks argument parsing); never `-R`
    (binds host `/etc/passwd`, breaking useradd/dpkg);
  - **`--root-id` bypasses DAC checks** for the tracee — writes into
    mode-555 dirs succeed, so permission tests must run with the plain
    (non-root) runner;
  - orphaned child processes (e.g. an LSP server outliving nvim) get reaped
    by proot and their exit status replaces the real one — stop LSP clients
    before `:qa` in headless tests and assert on output markers, not rc.
- Neovim 0.12 deprecations that make `--headless` exit 7:
  `vim.lsp.with()`, `vim.lsp.handlers[...]`, and the dot-form
  `client.supports_method(...)` (use `client:supports_method(...)`).
  Borders now go per-call: `vim.lsp.buf.hover({ border = 'rounded', title = 'hover' })`.
- `nvim-autopairs.completion.cmp` has **no** `setup()`; only the main
  `nvim-autopairs` module does. Calling it aborts the whole init.
- rust-analyzer at `lib/rust/bin/rust-analyzer` (RUNPATH `$ORIGIN/../lib`
  finds `librustc_driver`); `rust-objcopy` needed a relative
  `libLLVM.so…` symlink into `rustlib/…/lib` to satisfy its RUNPATH.
- Tree-sitter grammars must be pinned to the revisions declared by
  nvim-treesitter `main`'s `parsers.lua`, and compiled with gcc **inside**
  the 22.04 sandbox (host gcc would target a newer glibc).

## 9. File map

```
nvim-forge/
  config/            init.lua, colors/forge.lua, lua/forge/*.lua
  dist/              .deb, SHA256SUMS, TEST-REPORT.md
  docs/CHEATSHEET.md user keymap/command reference
  manifest/          pins.json, pins-locked.json, MANIFEST.md
  packaging/         control.in, changelog, copyright, launcher
  scripts/           build-all.sh + individual pipeline steps
  sandbox/           proot rootfses (build + test)
  tests/             netguard.c, startup.lua, treesitter.lua,
                     lsp_attach.lua, samples/
  cache/             downloaded, checksum-verified artifacts
```
