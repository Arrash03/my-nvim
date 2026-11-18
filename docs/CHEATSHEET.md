# nvim-forge cheatsheet

Leader = **Space**. Mode column: `n` normal, `i` insert, `v` visual, `t` terminal.
`<leader>` = Space. Launch with `nvim-forge [file]`.

## 1. Start / stop / everyday

| Keys | Mode | Action |
|---|---|---|
| `nvim-forge file.py` | — | open a file (any number of files) |
| `nvim-forge --version` | — | show bundled Neovim version |
| `<leader>w` | n | save file |
| `<leader>W` | n | save all open files |
| `<leader>q` | n | quit |
| `<leader>Q` | n | quit all |
| `:w name` | — | save as |
| `:wq` / `:x` / `ZZ` | — | save and quit |
| `:qa!` | — | quit all, discard changes |
| `u` / `<C-r>` | n | undo / redo |
| `.` | n | repeat last change (superpower) |

## 2. LSP (Python, C, C++, Rust)

Buffer-local — active once the server attaches (automatic on opening a
`.py` / `.c` / `.cpp` / `.rs` file; check with `:LspInfo`).

| Keys | Mode | Action |
|---|---|---|
| `gd` | n | go to definition |
| `gD` | n | go to declaration |
| `gr` | n | references (telescope-style list) |
| `gi` | n | implementations |
| `gt` | n | type definition |
| `K` | n | hover documentation (float) |
| `<C-k>` | n | signature help (float) |
| `<leader>rn` | n | rename symbol (all references) |
| `<leader>ca` | n,v | code action |
| `[d` / `]d` | n | previous / next diagnostic (float follows) |
| `<leader>d` | n | show diagnostic details as float |
| `<leader>ql` | n | diagnostics of this file → location list |
| `<leader>ih` | n | toggle Rust inlay hints (on by default) |

Extras that work without keymaps:

- **Document highlight**: identifiers under the cursor highlight while
  paused (`CursorHold`), cleared on move. Needs `updatetime` (300 ms).
- **Rust**: type hints + enum-entry hints enabled; binding/chaining/parameter
  hints deliberately off. `RUST_SRC_PATH` is set, so `gd` jumps into
  `std::` sources.
- **clangd**: picks up `compile_commands.json` by searching upward from the
  file; also runs clang-tidy.
- **BasedPyright**: runs on the bundled Node.js; `typeCheckingMode=standard`.
- Servers attach per buffer; diagnostics use `E W I H` signs, virtual text
  (`●`) and underline.

## 3. Files, buffers, windows

| Keys | Mode | Action |
|---|---|---|
| `<leader>ff` | n | find files (Telescope, current dir) |
| `<leader>fo` | n | recent files |
| `<leader>fb` | n | open buffers (MRU sorted) |
| `<leader>fg` | n | live grep (ripgrep; falls back to grep → quickfix) |
| `<leader>fs` | n | document symbols (outline of current file) |
| `<leader>fd` | n | diagnostics picker (all buffers) |
| `<leader>fh` | n | help tags |
| `<leader>fr` | n | resume last picker |
| `[b` / `]b` | n | previous / next buffer |
| `<leader>e` | n | toggle the file explorer sidebar (nvim-tree) |
| `<leader>E` | n | reveal the current file in the explorer |
| `<C-h/j/k/l>` | n | move between windows (left/down/up/right) |
| `:split` / `:vsplit` | — | split horizontally / vertically |
| `:tabnew file` | — | new tab |
| `[q` / `]q` | n | previous / next quickfix entry |
| `:copen` / `:lopen` | — | open quickfix / location list |

Inside any Telescope picker:

| Keys | Action |
|---|---|
| `<C-j>` / `<C-k>` | move selection down / up |
| `<CR>` | open (current window) |
| `<C-x>` / `<C-v>` / `<C-t>` | open in vertical split / horizontal split / new tab |
| `<Tab>` then `<CR>` | multi-select several entries and open all |
| `<Esc>` | close picker |

Inside the file explorer (`<leader>e` opens/toggles it as a left sidebar;
opening a file keeps the tree visible). **It also opens automatically when
nvim-forge starts** (like VS Code's explorer), always at the **first level**
of the current directory. It never auto-expands to a file — expand folders
yourself with `Enter`/`o`/double-click to reach any level. Start with
`NVF_NO_TREE=1 nvim-forge` to disable the sidebar.

| Keys | Action |
|---|---|
| `<CR>` / `o` / double-click | open file or expand/collapse folder (keeps tree open) |
| `E` / `W` | expand all folders / collapse all back to first level |
| `<BS>` | close the parent folder and jump to it |
| `<leader>E` (from editor) | reveal current file — expands its parent folders |
| `<C-x>` / `<C-v>` / `<C-t>` | open in vertical / horizontal split / new tab |
| `a` | create file or directory (trailing `/` = directory) |
| `A` | create file/directory without moving the cursor |
| `r` / `R` | rename / bulk-rename |
| `d` / `D` | delete (trash) / permanently delete |
| `x` / `c` / `p` | cut / copy / paste |
| `m` | move (rename with target path) |
| `.` | toggle hidden files (dotfiles) |
| `H` | toggle gitignored files |
| `U` | toggle filters (clean style) |
| `I` | toggle icon visibility |
| `g?` | all-key help inside the tree |
| `q` / `<Esc>` | close the explorer |

Icons: the package installs Symbols Nerd Font and a fontconfig fallback rule,
so file/folder icons show up in normal terminals. If you still see empty
boxes, run with `NVF_ICONS=ascii nvim-forge` for plain `▸`/`▾` arrows (or
`NVF_ICONS=nerd` to force Nerd Font glyphs after installing such a font).

## 4. Editing

| Keys | Mode | Action |
|---|---|---|
| `J` / `K` (visual) | v | move selected block down / up (keeps selection) |
| `<C-d>` / `<C-u>` | n | half page down / up (cursor re-centred) |
| `n` / `N` | n | next / previous search match (re-centred) |
| `/pattern` `<CR>` | n | search forward; `n` to repeat, `<Esc>` clears highlight |
| `*` / `#` | n | search word under cursor forward / backward |
| `:%s/old/new/g` | — | substitute whole file |
| `:s/old/new/g` | — | substitute current line (visual selection with `:`) |
| `<Esc>` | n | clear search highlight |
| `qa…q` then `@@` | n | record / replay macro |

Auto behaviour (no keys needed):

- Tabs = 4 spaces for python/c/cpp/rust, 2 for lua; smart indent everywhere. Markdown uses 2-space indentation and prose-friendly defaults (see below).
- Yanked text flashes (`IncSearch` highlight).
- Cursor position restored when reopening a file.
- Files > 2 MiB open in "large file mode": no syntax highlight, no treesitter,
  no undo/swap (you get a notification).

### Reading Markdown

Opening a `.md` file gives you a readable view out of the box:

- **Syntax highlighting** via bundled `markdown` + `markdown_inline` Tree-sitter parsers (including inline code, links, emphasis, lists, headings, fenced blocks).
- **Soft wrapping** (`wrap`, `linebreak`, `breakindent`) so prose flows to the window width instead of running off-screen.
- **Concealed markup** (`conceallevel=2`, `concealcursor=""`) so `**bold**`, links, and similar markers render cleanly while you read.

Toggle back to raw markup when needed: `:set conceallevel=0 nowrap`.

## 5. Snippets (via `<Tab>` in insert mode)

Type a trigger, press `<Tab>`; jump between fields with `<Tab>` / `<S-Tab>`;
exit with `<CR>`. Sources: friendly-snippets (bundled) + nvim-forge extras:

| Language | Triggers (nvim-forge extras) |
|---|---|
| Python | `main`, `defm`, `cls`, `tdef`, `try` |
| C | `incg` (header guard from filename), `func`, `printf`, `fori` |
| C++ | `main`, `cls`, `rfor`, `uptr`, `catch` |
| Rust | `fnt` (test fn), `fnmain`, `sdef`, `st`, `implst`, `match` |

## 6. Completion (nvim-cmp, insert mode)

| Keys | Action |
|---|---|
| `<Tab>` / `<S-Tab>` | next / previous item; or snippet jump; or plain tab |
| `<CR>` | confirm selection (newline when menu closed) |
| `<C-e>` | abort / close menu |
| `<C-d>` / `<C-f>` | scroll docs window down / up |

Sources: LSP first, then snippets, then buffer words (min 3 chars).
`/` and `?` searches also get buffer-word completion.

## 7. Terminal + misc

| Keys | Mode | Action |
|---|---|---|
| `<Esc><Esc>` | t | leave terminal mode (then normal window keys work) |
| `q` | n | close `:help`, `:LspInfo`, quickfix, man pages |
| `:terminal` | — | open a terminal buffer |
| `:checkhealth` | — | self diagnostics |
| `:messages` | — | recent messages |
| `:set ft=rust` | — | force filetype (re-triggers treesitter/LSP) |
| `:LspInfo` | — | which server is attached to this buffer |
| `:help <topic>` | — | offline help (helptags shipped) |

## 8. Environment & state

- Writable state is per-user, never in `/opt`: `~/.local/state/nvim-forge`
  (shada, undo, LSP logs), `~/.cache/nvim-forge`, `~/.local/share/nvim-forge`.
- `NVF_HOME` points at the bundle (default `/opt/nvim-forge`); `PATH` gets
  bundled `rust/bin` + `node/bin` prepended, so `cargo`/`rustc`/`node`
  work inside `:!` and `:terminal` too.
- Works over SSH/tmux with true color: `export TERM=xterm-256color`
  (tmux: add `set -g default-terminal "tmux-256color"`).
- Nothing downloads at runtime: no `:TSInstall`, no Mason, no git plugins.
  New LSP servers/parsers require rebuilding the package.

## 9. Troubleshooting

| Symptom | Fix |
|---|---|
| No LSP on a file | `:set ft=python` (or c/cpp/rust), then `:LspInfo` |
| Weird display in tmux | see true-color note above |
| Slow open on huge file | expected: >2 MiB triggers large-file mode |
| Need logs | `~/.local/state/nvim-forge/lsp.log` |
| Reset user state | quit nvim-forge and delete the three dirs in §8 |
