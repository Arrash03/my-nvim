--[[
  File explorer sidebar (nvim-tree.lua).
  ---------------------------------------------------------------------------
  Opens as a vertical split on the left side of the screen and can be
  toggled at any time with <leader>e.  Opening a file from the tree keeps
  the sidebar visible so the directory structure stays beside your buffers.

  Everything is bundled under /opt/nvim-forge/plugins/nvim-tree.lua (with
  its nvim-web-devicons dependency); nothing is downloaded at runtime.
]]

local ok, nt = pcall(require, 'nvim-tree')
if not ok then
  vim.schedule(function()
    vim.notify('nvim-tree not available', vim.log.levels.WARN)
  end)
  return
end

-- Icon support ---------------------------------------------------------------
-- Nerd Font glyphs are private-use codepoints and only render when a Nerd
-- Font is available.  The .deb installs Symbols Nerd Font plus a fontconfig
-- fallback rule; where that is missing (e.g. a source checkout on a machine
-- without Nerd Fonts) fall back to plain arrows so the tree stays readable.
-- Override with NVF_ICONS=nerd or NVF_ICONS=ascii.
local icon_mode = vim.env.NVF_ICONS
if not icon_mode or icon_mode == '' then
  icon_mode = vim.fn.glob('/usr/share/fonts/truetype/nvim-forge/*.ttf') ~= ''
    and 'nerd' or 'ascii'
end
local use_nerd_icons = icon_mode ~= 'ascii'
vim.g.nvf_icons_mode = icon_mode  -- exposed for troubleshooting/tests

nt.setup({
  -- Take over netrw's directory browsing so `nvim-forge .` shows the tree.
  hijack_netrw = true,
  sync_root_with_cwd = true,
  reload_on_bufenter = true,
  respect_buf_cwd = true,

  view = {
    width = 34,
    side = 'left',
    preserve_window_proportions = true,
  },

  -- First level only by default: do not auto-expand the tree to reveal the
  -- current file.  Expand folders on demand with Enter/o/double-click, E for
  -- all levels, W to collapse back to the first level, and <leader>E to
  -- explicitly reveal the current file.
  update_focused_file = {
    enable = false,
    update_root = { enable = false },
  },

  renderer = {
    group_empty = true,
    highlight_git = false,
    full_name = false,
    highlight_opened_files = 'all',
    indent_markers = { enable = true },
    icons = use_nerd_icons and {
      show = { file = true, folder = true, folder_arrow = true, git = false },
    } or {
      -- No Nerd Font: show plain arrows instead of empty boxes.
      show = { file = false, folder = false, folder_arrow = true, git = false },
      glyphs = { folder = { arrow_closed = '▸', arrow_open = '▾' } },
    },
  },

  filters = {
    dotfiles = false,
    git_ignored = true,
  },

  -- The target machine is offline and may have no `git` binary at all;
  -- only enable the git status column when git actually exists.
  git = {
    enable = vim.fn.executable('git') == 1,
    ignore = true,
    show_on_dirs = false,
  },

  actions = {
    open_file = {
      quit_on_open = false,   -- keep the tree open beside the buffer
      resize_window = true,
      window_picker = { enable = true, exclude = { filetype = { 'NvimTree' } } },
    },
  },

  -- Never persist tree state into the user's session files.
  experimental = { session_restore_nvim = false },
})

-- Toggle mappings -----------------------------------------------------------
local api = require('nvim-tree.api')
local map = vim.keymap.set
local function toggle_tree()
  if api.tree.is_visible() then
    api.tree.close()
  else
    api.tree.open()
    -- Reopening always presents the first level; drill down on demand.
    pcall(api.tree.collapse_all)
  end
end
map('n', '<leader>e', toggle_tree,
  { desc = 'Toggle file explorer (nvim-tree)', nowait = true })
map('n', '<leader>E', function()
  api.tree.find_file({ open = true, focus = true })
end, { desc = 'Reveal current file in explorer', nowait = true })

-- Open many files from the tree, one per tab ---------------------------------
-- nvim-tree's built-in <C-t> opens only the file under the cursor.  These two
-- helpers make a batch of files a one-keystroke operation:
--   normal mode:  mark files with `m`, then <leader>tm
--   visual mode:  select files with v/V, then <C-t>
-- api.node.open.tab returns focus to the tree after each file, so you can
-- keep selecting without losing the directory structure.
local function open_files_in_tabs(nodes)
  local files = {}
  for _, node in ipairs(nodes or {}) do
    local path = node and node.absolute_path
    if path and node.type == 'file' and vim.fn.filereadable(path) == 1 then
      table.insert(files, node)
    end
  end
  if #files == 0 then
    vim.notify('No files selected for tabs', vim.log.levels.WARN)
    return
  end
  for _, node in ipairs(files) do
    pcall(api.node.open.tab, node)
  end
  pcall(api.marks.clear)
  vim.notify(string.format('Opened %d file(s) in tabs; gt/gT to switch', #files),
    vim.log.levels.INFO)
end

-- Useful defaults inside the tree window (nvim-tree also ships its own
-- buffer-local maps: a create, r rename, d delete, x cut, p paste, ...).
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'NvimTree',
  callback = function(ev)
    local b = { buffer = ev.buf, silent = true, nowait = true }
    vim.keymap.set('n', '<Esc>', api.tree.close,
      vim.tbl_extend('force', b, { desc = 'Close explorer' }))
    vim.keymap.set('n', 'q', api.tree.close,
      vim.tbl_extend('force', b, { desc = 'Close explorer' }))
    vim.keymap.set('n', '<leader>tm', function()
      open_files_in_tabs(api.marks.list())
    end, vim.tbl_extend('force', b, {
      desc = 'Open marked files in tabs (mark with m first)',
    }))
    vim.keymap.set('x', '<C-t>', function()
      local utils = require('nvim-tree.utils')
      open_files_in_tabs(utils.get_visual_nodes())
    end, vim.tbl_extend('force', b, {
      desc = 'Open selected files in tabs',
    }))
  end,
})

-- Open the explorer automatically at startup, like VS Code ------------------
-- Skipped for headless/embedded sessions, stdin, diff mode, commit-message
-- buffers, and when NVF_NO_TREE=1 is set in the environment.
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    if vim.env.NVF_NO_TREE and vim.env.NVF_NO_TREE ~= '' then
      return
    end
    if #vim.api.nvim_list_uis() == 0 then return end   -- --headless / --embed
    if vim.o.diff then return end                      -- nvim -d
    if vim.fn.argc() == 1 and vim.fn.argv(0) == '-' then return end
    local ft = vim.bo.filetype
    if ft == 'gitcommit' or ft == 'gitrebase' or ft == 'git' then return end

    pcall(api.tree.open)
    pcall(api.tree.collapse_all)
    -- Do not steal focus from the editor (VS Code keeps the cursor in the
    -- text buffer when the explorer is shown); harmless with one window.
    pcall(vim.cmd, 'wincmd p')
  end,
})
