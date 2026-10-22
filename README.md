# nvim-forge

A complete, self-contained, **offline** Neovim distribution for Ubuntu 22.04+
(amd64), packaged as a single `.deb`. It installs under `/opt/nvim-forge/`
with a launcher at `/usr/bin/nvim-forge` and **never touches** your existing
Neovim installation (`/usr/bin/nvim` is left alone).

Everything is bundled: editor, plugins, Tree-sitter parsers, language
servers, language toolchains, theme and configuration. After `dpkg -i` the
whole stack works with **no network access at all** — no plugin manager
downloads, no Mason, no npm/rustup/git/compiler needed on the target machine.

## Contents

| Component            | Version    | Notes                                        |
|----------------------|------------|----------------------------------------------|
| Neovim               | 0.12.6     | official x86_64 release build                |
| Node.js runtime      | 24.22.0    | bundled `node` only (no npm/npx/corepack)    |
| BasedPyright         | 1.40.2     | Python type checker (pyright fork)           |
| clangd               | 23.1.0     | C/C++ LSP server                             |
| Rust toolchain       | 1.99.1     | rustc, cargo, rust-std, rust-src             |
| rust-analyzer        | 1.99.1     | Rust LSP server + proc-macro server          |
| Tree-sitter parsers  | pinned     | python, c, cpp, rust (prebuilt `.so`)        |
| Plugins              | commit-pin | see `manifest/pins.json`                     |
| Theme                | —          | Kanagawa Dragon-derived "forge" dark theme   |

Plugins: `nvim-treesitter`, `nvim-lspconfig`, `nvim-cmp`, `cmp-nvim-lsp`,
`cmp-buffer`, `LuaSnip`, `friendly-snippets`, `lualine.nvim`,
`nvim-autopairs`, `telescope.nvim`, `plenary.nvim`, `nvim-tree.lua`
(+ `nvim-web-devicons`) — all pinned to exact
commits listed in `manifest/pins.json` / `manifest/pins-locked.json`.

## Install

```sh
sudo dpkg -i nvim-forge_1.0.0_amd64.deb
nvim-forge            # start the editor
```

Requirements on the target: Ubuntu 22.04+ amd64 (`libc6 >= 2.35`,
`libstdc++6`, `libgcc-s1` — declared in the package `Depends`). Nothing else:
no compiler, no node, no rustup, no git, no internet.

## Usage

```sh
nvim-forge                 # normal start
nvim-forge file.py         # open a file
nvim-forge --version       # bundled Neovim version
```

Everything user-specific (sessions, shada, plugins' state, LSP logs) is
written to standard XDG directories under
`~/.local/state/nvim-forge` and `~/.cache/nvim-forge`; the bundle under
`/opt/nvim-forge` is read-only at runtime. Nothing is hardcoded to a
particular home directory, and no root privileges are required to run it.

### Keymaps (leader = Space)

| Keys            | Action                                       |
|-----------------|----------------------------------------------|
| `gd`            | goto definition                              |
| `gr`            | references                                   |
| `K`             | hover documentation                          |
| `<leader>rn`    | rename symbol                                |
| `<leader>ca`    | code action                                  |
| `[d` / `]d`     | prev / next diagnostic                       |
| `<leader>e`     | toggle file explorer sidebar (nvim-tree)     |
| `<leader>E`     | reveal current file in the explorer          |
| `<leader>d`     | show diagnostic details as a float           |
| `<leader>ff`    | find files (Telescope)                       |
| `<leader>fg`    | live grep                                    |

### Language servers

* **Python** – BasedPyright; a project virtualenv (`/.venv`, `/venv`,
  `$VIRTUAL_ENV`) is auto-detected and put on the server's path.
* **C/C++** – clangd; picks up `compile_commands.json` from the file's
  directory upward.
* **Rust** – rust-analyzer with inlay hints enabled; `RUST_SRC_PATH` points
  at the bundled `rust-src`.

LSP is wired through Neovim's native `vim.lsp.config()` /
`vim.lsp.enable()` API (no legacy setup calls).

## Layout

```
/opt/nvim-forge/
  bin/nvim                 Neovim binary
  config/                  init.lua + lua/forge/* + colors/forge.lua
  plugins/                 commit-pinned plugins (runtimepath-loaded)
  parsers/parser/*.so      prebuilt Tree-sitter parsers
  lib/node/bin/node        Node.js runtime (BasedPyright)
  lib/rust/                rustc, cargo, rust-std, rust-src, rust-analyzer
  servers/basedpyright/    BasedPyright package
  servers/clangd/          clangd binary + libs
  manifest/                pins.json, pins-locked.json, MANIFEST.md
  licenses/                license texts of every bundled component
/usr/bin/nvim-forge        launcher script
```

A custom static runtimepath loader is used instead of lazy.nvim so that no
git or network access is ever required.

## Uninstall

```sh
sudo dpkg -r nvim-forge
```

Removes `/opt/nvim-forge` and `/usr/bin/nvim-forge`. Your per-user state
directories (`~/.local/state/nvim-forge`, `~/.cache/nvim-forge`) are left
in place; delete them manually if you want a full cleanup.

## Rebuilding from source

```sh
bash scripts/build-all.sh      # everything: fetch -> sandbox -> parsers ->
                               # stage -> ELF audit -> .deb -> test suite
```

or run the individual steps:

```sh
bash scripts/fetch.sh        # download + verify all pinned artifacts
bash scripts/sandbox.sh      # prepare Ubuntu 22.04 build/test rootfs (proot)
bash scripts/build-parsers.sh  # compile Tree-sitter parsers in 22.04 sandbox
bash scripts/stage.sh        # assemble /opt/nvim-forge tree
bash scripts/check-elf.sh    # audit shared libs / glibc ceilings
bash scripts/build-deb.sh    # produce dist/nvim-forge_1.0.0_amd64.deb
bash scripts/verify.sh       # run the offline test suite, write TEST-REPORT.md
```

Builds use a proot-based Ubuntu 22.04 sandbox (no Docker required).

## Known limitations

* amd64 only; requires glibc >= 2.35 (Ubuntu 22.04+).
* Tree-sitter parsers ship for python, c, cpp and rust only (pinned).
* No git, npm, cargo-registry or internet access at runtime by design —
  adding new LSP servers or parsers requires rebuilding the package.
* rust-analyzer and clangd require a writable home for their caches; they
  are configured to store logs under the per-user XDG state dir.
