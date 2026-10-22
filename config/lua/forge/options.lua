--[[
  General editor options for systems programming (Python / C / C++ / Rust).
  Kept intentionally small; every option below is there for a reason.
]]

local o = vim.opt

-- UI -----------------------------------------------------------------------
o.number = true              -- absolute line numbers ...
o.relativenumber = true      -- ... with relative numbers for navigation
o.signcolumn = 'yes'         -- never shift the buffer when diagnostics appear
o.cursorline = true          -- subtle current-line highlight
o.termguicolors = true       -- true-color terminal output
o.showmode = false           -- mode is shown by the statusline
o.cmdheight = 1
o.showmatch = true           -- flash matching bracket briefly
o.matchtime = 2
o.scrolloff = 5              -- keep context around the cursor
o.sidescrolloff = 8
o.wrap = false               -- code reads better unwrapped
o.list = false               -- whitespace glyphs off by default
o.mouse = 'a'                -- mouse support, but never required
o.splitright = true
o.splitbelow = true
o.confirm = true             -- ask instead of failing on :q with changes

-- Search -------------------------------------------------------------------
o.ignorecase = true
o.smartcase = true           -- case-sensitive when the pattern has caps
o.incsearch = true
o.hlsearch = true
o.inccommand = 'split'       -- live preview for :s substitutions

-- Editing ------------------------------------------------------------------
o.expandtab = true           -- spaces by default, incl. Python/C/C++/Rust
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.autoindent = true
o.smartindent = true
o.virtualedit = 'block'      -- blockwise editing past EOL
o.formatoptions:remove({ 'c', 'r', 'o' })  -- no auto comment continuation
o.formatoptions:append('j')  -- join removes comment leaders
o.undofile = true            -- persistent undo (lives in stdpath('state'))
o.swapfile = true
o.updatetime = 300           -- faster CursorHold (diagnostics, updates)
o.timeoutlen = 400
o.ttimeoutlen = 50
o.confirm = true

-- Completion ---------------------------------------------------------------
o.completeopt = { 'menu', 'menuone', 'noselect' }
o.shortmess:append('c')      -- don't spam completion messages

-- Files ------------------------------------------------------------------
o.fileencoding = 'utf-8'
o.backup = false            -- undo covers the backup use-case
o.writebackup = false

-- Windows ------------------------------------------------------------------
o.pumheight = 12             -- cap the completion menu height
o.winminwidth = 5
o.fillchars:append({ eob = ' ' })

-- Behaviour with large files ----------------------------------------------
-- (see forge.autocmds for the LargeFile handler)

-- Folding: gentle defaults; treesitter folds only where a parser exists.
o.foldmethod = 'indent'
o.foldlevel = 99
o.foldlevelstart = 99
o.foldenable = false
