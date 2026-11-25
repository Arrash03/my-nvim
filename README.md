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
| Tree-sitter parsers  | pinned     | python, c, cpp, rust, markdown (prebuilt `.so`) |
| Plugins              | commit-pin | see `manifest/pins.json`                     |
| Icons (font)         | 3.5.1      | Symbols Nerd Font + fontconfig fallback rule |
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
| `<leader>ca`    | code action (choose from all available)      |
| `<leader>cf`    | apply first clangd quick fix (or choose)      |
| `<leader>lf`    | list/choose quick fixes only                 |
| `<leader>fn`    | toggle "fix available" notices (C/C++ buffers)|
| `<leader>lr` / `<leader>lc` | restart all LSP clients / clangd only |
| `<leader>cd`    | set clangd `compile_commands.json` dir + restart |
| `<leader>fi`    | toggle live diagnostics while typing         |
| `[d` / `]d`     | prev / next diagnostic                       |
| `<leader>t`     | open a new tab                               |
| `gt` / `gT`     | next / previous tab (`2gt` = go to tab 2)    |
| `<leader>tc` / `<leader>to` | close tab / keep only this tab    |
| `<leader>tf` / `<leader>tl` | first / last tab                 |
| `<leader>gt`    | LSP: go to type definition (`gt` stays "next tab") |
| `<leader>e`     | toggle file explorer sidebar (nvim-tree)     |
| `<leader>E`     | reveal current file in the explorer          |
| `<leader>d`     | show diagnostic details as a float           |
| `<leader>ff`    | find files (Telescope)                       |
| `<leader>fg`    | live grep                                    |
| `<leader>fG`    | grep with include/exclude file filters       |
| `<leader>gc`    | Git: list changed/untracked files            |
| `<leader>gb`    | Git: toggle inline blame                     |
| `<leader>gR`    | Git: refresh change marks and blame          |
| `[g` / `]g`     | prev / next changed line in current buffer   |

### Search only selected files

`<leader>fG` asks for three things:

1. the search pattern,
2. **include** globs — comma-separated, for example `*.py,src/*.c`; leave blank for all files,
3. **exclude** globs — comma-separated, for example `test_*.py,*.min.js,vendor/`; leave blank for none.

A glob ending in `/` excludes that directory (e.g. `vendor/`). With ripgrep
available this opens Telescope’s live grep with `rg --glob` filters; on the
offline target it runs `grep -rn` with `--include`/`--exclude`/`--exclude-dir`
and fills the quickfix list. `<C-t>` still opens any result in another tab.

### Indentation

Pressing `Tab` inserts a **real tab by default** in every file — including
files with no detected filetype — displayed 4 columns wide. This covers
C, C++, Rust, and CMake without any extra setup. Only explicit exceptions opt
into spaces: Python uses **4 spaces**, Lua uses **2 spaces**, and Markdown uses
2 spaces with prose-friendly wrapping.

### File explorer

The sidebar opens automatically at startup (like VS Code) showing only the
**first level** of the current directory — even when you open a file in a
nested folder. Open folders on demand with `Enter`/`o`/double-click to reach
any level; `E` expands everything and `W` collapses everything back to the
first level. `<leader>e` toggles the tree (reopens at first level),
`<leader>E` explicitly reveals the current file, expanding its parent
folders. Set `NVF_NO_TREE=1` in the environment to start without it. Inside
the tree: `<CR>` open, `<C-t>` open in a new tab, `<C-v>`/`<C-x>` split, `a`
create, `r` rename, `d` delete, `x`/`c`/`p` cut/copy/paste, `m` mark a file,
`H` toggle hidden files, `g?` full key help, `q`/`<Esc>` close.

To open **many files from the tree, each in its own tab**:
- Mark the files one by one with `m` (or select several with `v`/`V` and press
  `m` to mark them all), then press `<leader>tm`.
- Or select consecutive files with `v`/`V` and press `<C-t>` directly.

The explorer stays open while each file opens in its own tab; `gt`/`gT`
switch between them afterwards.

File and folder icons are Nerd Font glyphs. The package installs **Symbols
Nerd Font** plus a fontconfig rule that adds it as a fallback for common
monospace families (Ubuntu Mono, DejaVu Sans Mono, Liberation Mono, JetBrains
Mono, …), so the icons render without changing your terminal font. On a
terminal that does not use fontconfig, set `NVF_ICONS=ascii` to get plain
`▸`/`▾` arrows instead of empty boxes; `NVF_ICONS=nerd` forces the glyphs.

### Tabs (many files)

Neovim tabs are like VS Code editor groups/tabs. A tab bar appears as soon as
you have two or more tabs.

- Open several files as tabs in one command:
  `nvim-forge -p file1.c file2.c file3.py`
- From the explorer: put the cursor on a file and press `<C-t>` for one file,
  or mark several files with `m` and press `<leader>tm` (or visually select
  them and press `<C-t>`) to open each in a tab in one go.
- From a Telescope picker (`<leader>ff`, `<leader>fg` with `rg`, `<leader>fb`,
  …): select a file or text match and press `<C-t>` to open it in a new tab;
  `<C-v>`/`<C-x>` open splits instead.
- Text search without `rg` uses a quickfix list (`<leader>fg`). Put the cursor
  on a match and press `<C-t>` to open that file at the matching line in a new
  tab. The same key works in location lists, Git change lists, diagnostics,
  and LSP reference lists.
- In an editor buffer: `<leader>t` for a new empty tab, `:tabnew file.c` for a
  specific file.
- Switch: `gt` / `gT` (next / previous), `2gt` / `3gt` (go to tab number),
  `<leader>tf` / `<leader>tl` (first / last), or click a tab in the tab bar.
- Close: `<leader>tc` (close current tab), `<leader>to` (keep only this tab),
  `:tabclose 2` (close tab 2). `:tabmove 3` reorders the current tab.
- Each tab keeps its own splits and explorer visibility. Files are buffers —
  the same file can be visible in several tabs; edits stay in sync.

### Autocomplete and suggestions

Completion starts automatically while you type, using (in order) **language
server suggestions**, **snippets**, and **words from the current buffer**.
Suggestions appear in a bordered menu with a kind label (`fn`, `var`, `cls`, …)
and a source label (`LSP`, `Snip`, `Buf`).

- `<C-Space>` — open the suggestion menu explicitly
- `<Tab>` / `<S-Tab>` — next / previous suggestion, or expand/jump snippets
- `<CR>` — accept the first suggestion; if the menu is closed, insert a newline
- `<C-e>` — dismiss the menu; `<C-d>` / `<C-f>` — scroll the documentation
- `<C-y>` — confirm the highlighted entry (nvim-cmp default)

LSP-backed completion is registered for Python, C, C++, and Rust with snippet
support, so server suggestions (including function signatures and snippets)
appear alongside your own buffer words. Search `/` and `?` also complete from
the current buffer. No network or plugin download is involved.

### Command-line suggestions

In `:` command mode, type part of a command, file name, option, or help tag and
press `Tab`. A popup lists all matches; press `Tab` again (or `Shift-Tab`) to
cycle through them, then `Enter` to run the completed command. Case is ignored,
and `.git`, `node_modules`, `target`, and `__pycache__` paths are skipped.

### Git Lens and blame (optional)

Git is **not bundled** — the editor remains fully offline and works without
it. When `git` is on `PATH`, nvim-forge adds VS Code–style Git Lens helpers:

- `+` / `-` signs in the signcolumn for added and deleted lines in the current
  file, covering both staged and unstaged changes. Modified lines show both a
  `-` on the old line and a `+` on the new one. Marks refresh when you enter a
  file and after `:w`.
- Inline blame: `<leader>gb` (or `:NVFGitBlame`) toggles compact
  `author · date · commit summary` text at the end of every line.
- Changed files: `<leader>gc` (or `:NVFGitChanges`) opens a quickfix list of
  every modified, staged, added, deleted, renamed and untracked file in the
  repository. The explorer also highlights changed files when git is present.
- `[g` / `]g` jump between changed lines in the current file.
- `:NVFGitRefresh` rebuilds the marks (also bound to `<leader>gR`).

Without `git`, all of these are safe no-ops with a warning, and the rest of
nvim-forge is unaffected.

### Language servers

* **Python** – BasedPyright; a project virtualenv (`/.venv`, `/venv`,
  `$VIRTUAL_ENV`) is auto-detected and put on the server's path.
* **C/C++** – clangd (with clang-tidy); pick up `compile_commands.json` in any
  of the ways described below.
* **Rust** – rust-analyzer with inlay hints enabled; `RUST_SRC_PATH` points
  at the bundled `rust-src`.

LSP is wired through Neovim's native `vim.lsp.config()` /
`vim.lsp.enable()` API (no legacy setup calls). `:lsp restart [client]`
restarts servers (Neovim 0.12 built-in); `<leader>lr` restarts the clients
attached to the current buffer and `<leader>lc` restarts clangd only.

### C/C++: giving clangd a compile database

clangd needs a compilation database (`compile_commands.json`) to know your
include paths and defines. Any of these work, from most to least convenient:

1. **Project root** — put `compile_commands.json` in your project root (or a
   `build/` subdirectory). clangd searches upward from each source file and
   finds it automatically. Nothing else to configure.
2. **Project `.clangd` file** — if the database lives elsewhere, create a
   `.clangd` file in the project root:

   ```yaml
   CompileFlags:
     CompilationDatabase: /absolute/path/to/build
   ```

   clangd is launched with `--enable-config`, so this is read automatically.
3. **Environment variable** — before starting nvim-forge:

   ```sh
   NVF_CLANGD_COMPILE_COMMANDS_DIR=/path/to/build nvim-forge src/main.c
   ```

4. **At runtime** — press `<leader>cd` (or run `:NVFCompileDB /path/to/build`).
   It accepts a directory or the path to a `compile_commands.json` file,
   updates clangd's `--compile-commands-dir` argument and restarts clangd, so
   a newly generated database is picked up immediately. This also works when
   clangd is not running yet — the new path is used when it next attaches.

### Diagnostics, notifications and applying fixes

While you edit, diagnostics appear as `E W I H` signs, virtual text (`●`) and
underlines. `<leader>fi` toggles *live* updates while still in insert mode;
`<leader>d` opens the full message and `[d` / `]d` jump between problems.

For C/C++ files, press `<leader>fn` once to turn on "fix available" notices:
when you rest the cursor on a diagnostic, nvim-forge tells you how many clangd
quick fixes exist there. Then:

* `<leader>ca` — choose from **all** code actions (refactors, source actions,
  quick fixes, …) in a picker; selecting one applies it.
* `<leader>lf` — same picker, filtered to quick fixes only.
* `<leader>cf` — apply a single available quick fix immediately; if more than
  one exists, the picker opens so you can choose.

Put the cursor on the diagnostic (or select a range in visual mode) before
opening the action menu — LSP code actions are requested for that position.

Fixes are applied as normal LSP workspace edits, so `:undo` reverses them.

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

/usr/share/fonts/truetype/nvim-forge/SymbolsNerdFont*.ttf   icon glyphs
/etc/fonts/conf.d/10-nerd-font-symbols.conf                 fallback rule
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
bash scripts/build-proot.sh   # build the proot sandbox tool (once)
bash scripts/fetch.sh        # download + verify all pinned artifacts
bash scripts/sandbox.sh      # prepare Ubuntu 22.04 build/test rootfs (proot)
bash scripts/build-parsers.sh  # compile Tree-sitter parsers in 22.04 sandbox
bash scripts/stage.sh        # assemble /opt/nvim-forge tree
bash scripts/check-elf.sh    # audit shared libs / glibc ceilings
bash scripts/build-deb.sh    # produce dist/nvim-forge_1.0.0_amd64.deb
bash scripts/verify.sh       # run the offline test suite, write TEST-REPORT.md
```

Builds use a proot-based Ubuntu 22.04 sandbox (no Docker required).

## Continuous deployment

Every push to `master` triggers `.github/workflows/build-deb.yml`, which on
a clean Ubuntu 24.04 runner:

1. installs host tooling (jq, gcc, libtalloc-dev, ...),
2. builds proot (`scripts/build-proot.sh`, with a vendored-talloc fallback),
3. restores the checksum-pinned download cache (keyed on
   `manifest/pins-locked.json`),
4. runs `scripts/build-all.sh` (fetch + verify pins → 22.04 sandbox →
   Tree-sitter parsers → stage → ELF audit → .deb → 16-check suite),
5. uploads the .deb / SHA256SUMS / TEST-REPORT.md as run artifacts, and
6. re-publishes them on the rolling **`continuous`** prerelease (the tag and
   release are refreshed in place on every push; the release notes carry the
   commit, SHA-256 and test tally).

## Known limitations

* amd64 only; requires glibc >= 2.35 (Ubuntu 22.04+).
* Tree-sitter parsers ship for python, c, cpp, rust and markdown (pinned).
* No git, npm, cargo-registry or internet access at runtime by design —
  adding new LSP servers or parsers requires rebuilding the package.
* rust-analyzer and clangd require a writable home for their caches; they
  are configured to store logs under the per-user XDG state dir.
