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
| `dist/nvim-forge_1.0.0_amd64.deb` | 289 MB | ~1.18 GB installed |
| `dist/SHA256SUMS` | — | checksum of the .deb |
| `dist/TEST-REPORT.md` | — | offline acceptance results |

SHA-256 of the .deb:
`73040d7cc9724dd180121a93811722e2ac675f64c065c325657b6848567bd6ff`

Package metadata: `Depends: libc6 (>= 2.35), libgcc-s1, libstdc++6`,
`Recommends: fontconfig`, `Architecture: amd64`. The only maintainer scripts
are a guarded `fc-cache -f` in `postinst`/`postrm` so the bundled Symbols
Nerd Font (installed under `/usr/share/fonts/truetype/nvim-forge/` with a
fontconfig fallback rule in `/etc/fonts/conf.d/`) is picked up immediately;
installation makes no network access and no other system changes.

## 3. Bundled versions

| Component | Version |
|---|---|
| Neovim | 0.12.6 (official x86_64 build) |
| Node.js runtime | 24.22.0 (binary only; no npm/npx/corepack) |
| BasedPyright | 1.40.2 (Python LSP, runs on bundled node) |
| clangd | 23.1.0 (C/C++) |
| Rust toolchain | 1.99.1 (rustc, cargo, rust-std, rust-src) |
| rust-analyzer | 1.99.1 (+ proc-macro server inside rustc) |
| Tree-sitter parsers | python v0.25.0, c b780e47f, cpp c0092228, rust 77a37472, markdown/markdown_inline a0a00f81 |
| Icons | Symbols Nerd Font 3.5.1 (Nerd Fonts) + fontconfig fallback rule |
| Plugins | 13, commit-pinned (nvim-treesitter, nvim-lspconfig, nvim-cmp, cmp-nvim-lsp, cmp-buffer, LuaSnip, friendly-snippets, lualine.nvim, nvim-autopairs, telescope.nvim, plenary.nvim, nvim-tree.lua + nvim-web-devicons) |
| Theme | custom "forge" (Kanagawa Dragon-derived, bg ≈ #0D0F12) |

All pins live in `manifest/pins.json` + `manifest/pins-locked.json`
(SHA-256 self-pinned; Node/Rust additionally verified against upstream
checksum files at fetch time). License texts of all 22 components ship in
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

Tabs work like editor groups: `nvim-forge -p f1 f2 f3` opens several files as
tabs, `<C-t>` in the explorer/Telescope opens a selected file in a new tab.
To open **many files from the explorer at once**, mark them with `m` and press
`<leader>tm`, or visually select them with `v`/`V` and press `<C-t>`; each
file gets its own tab while the tree stays open. `<leader>t` opens an empty
tab, and `gt`/`gT` (or `2gt`, mouse click) switch
between them. `gt` is reserved for tabs even in LSP buffers — type definition
was moved to `<leader>gt`. `<leader>tc`/`<leader>to` close tabs, and
`<leader>tf`/`<leader>tl` jump to first/last.

Optional Git Lens works without bundling git: when a `git` executable is on
`PATH`, added/deleted lines get signcolumn marks (staged + unstaged),
`:NVFGitBlame` (`<leader>gb`) overlays compact author/date/summary blame text,
`:NVFGitChanges` (`<leader>gc`) lists every changed/untracked file in the
quickfix list, and `[g`/`]g` jump between changed lines. The explorer also
highlights changed files. Without git these commands are safe no-ops, so the
"no git required on target" guarantee is preserved.

Completion is nvim-cmp with LSP, LuaSnip/friendly-snippets and current-buffer
sources, plus a secondary buffer source for short words. Suggestions are shown
in a bordered menu with kind/source labels; `<C-Space>` opens it explicitly,
`<Tab>`/`<S-Tab>` navigate, and `<CR>` accepts the first item even with
`completeopt=noselect`. `cmp_nvim_lsp` registers snippet-capable completion
capabilities with every server. Acceptance T18 drives the real buffer source
and asserts that a partial word returns the full identifier.

C/C++ compile database and fixes can be handled entirely from the editor:
`compile_commands.json` in the project root (or `build/`) is found
automatically; a project `.clangd` file with
`CompileFlags.CompilationDatabase` is honoured because clangd is launched
with `--enable-config`; `NVF_CLANGD_COMPILE_COMMANDS_DIR=...` sets the path at
launch; and `<leader>cd` / `:NVFCompileDB <dir>` changes it live and restarts
clangd via Neovim 0.12's built-in `:lsp restart clangd`. `<leader>fn` opts in
to "N fixes available" notices while the cursor rests on a diagnostic;
`<leader>ca` (all actions), `<leader>lf` (quick fixes only) and `<leader>cf`
(apply the first one) use the native LSP code-action picker and apply the
result as a workspace edit, so `:undo` reverses it. `<leader>lr` restarts all
LSP clients attached to the current buffer.

## 5. Rebuild from source

```sh
bash scripts/build-all.sh    # one shot: fetch → sandbox → parsers →
                             # stage → ELF audit → .deb → test suite
```

Individual steps: `fetch.sh` (download+verify pins) → `sandbox.sh`
(prepare Ubuntu 22.04 proot rootfses) → `build-parsers.sh` (compile
grammars inside the 22.04 sandbox) → `stage.sh` (assemble /opt tree) →
`check-elf.sh` (ldd + glibc ceilings) → `build-deb.sh` → `verify.sh`
(19-check offline acceptance suite, writes `dist/TEST-REPORT.md`).

## 6. Test results — 19/19 PASS

Run in a pristine ubuntu-base-22.04.5 rootfs (see §8 for why proot):

| ID | Check |
|---|---|
| T01 | SHA256SUMS + package metadata |
| T02 | clean `dpkg -i`; system `/usr/bin/nvim` untouched |
| T03 | `nvim-forge --version` → NVIM v0.12.6 |
| T04 | headless startup: theme, options, plugins, LSP config (incl. `:lsp restart`, `:NVFCompileDB`, clangd `--enable-config`), exes |
| T05 | Tree-sitter parses python/c/cpp/rust/markdown; highlighter attaches |
| T06–T09 | LSP attach: basedpyright, clangd (c), clangd (cpp), rust_analyzer |
| T10 | ldd over all 43 installed ELF files — nothing unresolved |
| T11 | runs as non-root uid 1000, XDG state created |
| T12 | bundle read-only (write probe refused), editor still starts |
| T13 | fully offline: startup + all 3 servers with sockets blocked; strace saw 0 AF_INET syscalls |
| T14 | no hardcoded `/home` paths in config/launcher |
| T15 | icons: Symbols Nerd Font + fontconfig fallback installed; explorer uses nerd glyphs |
| T16 | batch-open many files from explorer in tabs (mark+`<leader>tm`, visual+`<C-t>`) |
| T17 | Git Lens: blame text, change signs, changed-file quickfix, `[g`/`]g` (fake-git stub) |
| T18 | completion: LSP/snippet/buffer sources, mappings, live buffer suggestion |
| T19 | `dpkg -r` removes bundle+launcher; system nvim and user state kept |

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
- Tree-sitter parsers ship for python/c/cpp/rust/markdown only.
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
  packaging/         control.in, changelog, copyright, launcher, postinst,
                     postrm (fontcache refresh only)
  scripts/           build-all.sh + individual pipeline steps
  sandbox/           proot rootfses (build + test)
  tests/             netguard.c, startup.lua, treesitter.lua,
                     lsp_attach.lua, samples/
  cache/             downloaded, checksum-verified artifacts
```
