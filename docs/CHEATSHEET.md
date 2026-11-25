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
`.py` / `.c` / `.cpp` / `.rs` file; check with `:checkhealth vim.lsp` or
`:lua vim.print(vim.lsp.get_clients({bufnr=0}))`).

| Keys | Mode | Action |
|---|---|---|
| `gd` | n | go to definition |
| `gD` | n | go to declaration |
| `gr` | n | references (telescope-style list) |
| `gi` | n | implementations |
| `<leader>gt` | n | type definition (`gt` is reserved for next tab) |
| `K` | n | hover documentation (float) |
| `<C-k>` | n | signature help (float) |
| `<leader>rn` | n | rename symbol (all references) |
| `<leader>ca` | n,v | code action — choose from all actions, then apply |
| `<leader>lf` | n,v | choose from **quick fixes only**, then apply |
| `<leader>cf` | n,v | apply the first quick fix (picker if several) — cursor must be on the diagnostic |
| `<leader>fn` | n | toggle clangd "fix available" notices (C/C++ only) |
| `[d` / `]d` | n | previous / next diagnostic (float follows) |
| `<leader>d` | n | show diagnostic details as float |
| `<leader>ql` | n | diagnostics of this file → location list |
| `<leader>ih` | n | toggle Rust inlay hints (on by default) |

Global (any buffer):

| Keys | Mode | Action |
|---|---|---|
| `:lsp restart [clangd]` | — | restart LSP clients (Neovim 0.12 built-in) |
| `<leader>lr` | n | restart all LSP clients attached to this buffer |
| `<leader>lc` | n | restart clangd only |
| `<leader>cd` | n | prompt for `compile_commands.json` dir, update clangd + restart (`:NVFCompileDB <dir>`) |
| `<leader>fi` | n | toggle live diagnostics while still in insert mode |

Extras that work without keymaps:

- **Document highlight**: identifiers under the cursor highlight while
  paused (`CursorHold`), cleared on move. Needs `updatetime` (300 ms).
- **Rust**: type hints + enum-entry hints enabled; binding/chaining/parameter
  hints deliberately off. `RUST_SRC_PATH` is set, so `gd` jumps into
  `std::` sources.
- **clangd**: runs clang-tidy and reads project `.clangd` files
  (`--enable-config`). It finds `compile_commands.json` by searching upward
  from the source file (including a `build/` subdirectory). To point it at a
  database elsewhere, either add a `.clangd` file with
  `CompileFlags: CompilationDatabase: /path/to/build`, set
  `NVF_CLANGD_COMPILE_COMMANDS_DIR=/path/to/build` before launching, or press
  `<leader>cd` at runtime. All of these restart clangd where needed.
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
| `<leader>fG` | n | grep with include/exclude file globs |
| `<leader>fs` | n | document symbols (outline of current file) |
| `<leader>fd` | n | diagnostics picker (all buffers) |
| `<leader>fh` | n | help tags |
| `<leader>fr` | n | resume last picker |
| `[b` / `]b` | n | previous / next buffer |
| `<leader>e` | n | toggle the file explorer sidebar (nvim-tree) |
| `<leader>E` | n | reveal the current file in the explorer |
| `<C-h/j/k/l>` | n | move between windows (left/down/up/right) |
| `:split` / `:vsplit` | — | split horizontally / vertically |

`<leader>fG` prompts for a pattern, include globs, and exclude globs. Use
comma-separated globs:

```text
Include: *.py,src/*.c
Exclude: test_*.py,*.min.js,vendor/
```

Leave include blank for all files, exclude blank for none. A trailing `/`
excludes a directory (`vendor/`). With `rg`, results open in Telescope with
`--glob` filters; without `rg`, the offline `grep` fallback fills quickfix.

Tabs (open many files, then switch):

| Keys | Mode | Action |
|---|---|---|
| `nvim-forge -p f1.c f2.c f3.py` | shell | open each file in its own tab |
| `<leader>t` | n | new tab |
| `<C-t>` in explorer / Telescope | n | open the selected file or search match in a new tab |
| `<C-t>` in quickfix / location list | n | open the entry under the cursor in a new tab |
| `gt` / `gT` | n | next / previous tab (`2gt` → tab 2) |
| `<leader>tf` / `<leader>tl` | n | first / last tab |
| `<leader>tc` / `<leader>to` | n | close tab / keep only this tab |
| `:tabnew file`, `:tabclose [n]`, `:tabmove [n]` | — | new / close / reorder tab |

`gt` / `gT` work in LSP buffers too — type definition moved to `<leader>gt`.
The tab bar appears when there are 2+ tabs; you can also click a tab. Each
tab has its own splits; buffers are shared, so edits stay in sync.

Git Lens / blame (optional: needs `git` on PATH; no-op without it):

| Keys | Mode | Action |
|---|---|---|
| `<leader>gc` / `:NVFGitChanges` | n / — | list all changed/untracked files in quickfix |
| `<leader>gb` / `:NVFGitBlame` | n / — | toggle inline blame on current buffer |
| `<leader>gR` / `:NVFGitRefresh` | n / — | refresh change signs + blame |
| `[g` / `]g` | n | previous / next changed line in current file |
| `+` / `-` signcolumn marks | — | added / deleted lines (staged + unstaged) |

The explorer also highlights modified files when git is available. Git is not
bundled; the editor stays fully offline and works without it.

| Keys | Mode | Action |
|---|---|---|
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
| `m` | toggle a mark/bookmark (in visual mode: mark all selected files) |
| `<leader>tm` | open **all marked files, each in its own tab** |
| `<C-t>` in visual mode | open **all selected files, each in its own tab** |
| `a` | create file or directory (trailing `/` = directory) |
| `A` | create file/directory without moving the cursor |
| `e` / `r` / `R` | rename basename / rename / bulk-rename |
| `gp` | move (rename with target path) |
| `d` / `D` | delete (trash) / permanently delete |
| `x` / `c` / `p` | cut / copy / paste |
| `f` / `F` | live filter / clear live filter |
| `.` | run a shell command on the file |
| `H` / `I` | toggle dotfiles / gitignored files |
| `g?` | all-key help inside the tree |
| `q` / `<Esc>` | close the explorer |

`gt`/`gT` switch tabs afterwards; the tree stays open while files are opened.

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

- Pressing `Tab` inserts a real tab in C/C++/Rust/CMake (displayed 4 columns)
  and **4 spaces** in Python. Lua uses 2 spaces; Markdown uses 2 spaces and
  prose-friendly defaults. Smart indent is enabled everywhere.
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
| *(automatic)* | menu opens as you type |
| `<C-Space>` | open the suggestion menu explicitly |
| `<Tab>` / `<S-Tab>` | next / previous item; or snippet jump; or plain tab |
| `<CR>` | accept the first suggestion (newline when menu closed) |
| `<C-y>` | confirm the highlighted entry |
| `<C-e>` | abort / close menu |
| `<C-d>` / `<C-f>` | scroll docs window down / up |

Sources: LSP first, then snippets, then buffer words (min 2 chars). Each entry
shows a kind (`fn`, `var`, `cls`, …) and source (`LSP`, `Snip`, `Buf`).
`/` and `?` searches also get buffer-word completion.

## 7. Terminal + misc

| Keys | Mode | Action |
|---|---|---|
| `<Esc><Esc>` | t | leave terminal mode (then normal window keys work) |
| `q` | n | close `:help`, `:checkhealth`, quickfix, man pages |
| `:terminal` | — | open a terminal buffer |
| `:checkhealth` | — | self diagnostics |
| `:messages` | — | recent messages |
| `:set ft=rust` | — | force filetype (re-triggers treesitter/LSP) |
| `:checkhealth vim.lsp` | — | which server is attached to this buffer |
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
| No LSP on a file | `:set ft=python` (or c/cpp/rust), then `:checkhealth vim.lsp` |
| Weird display in tmux | see true-color note above |
| Slow open on huge file | expected: >2 MiB triggers large-file mode |
| Need logs | `~/.local/state/nvim-forge/lsp.log` |
| Reset user state | quit nvim-forge and delete the three dirs in §8 |
