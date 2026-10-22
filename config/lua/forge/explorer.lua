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

  renderer = {
    group_empty = true,
    highlight_git = false,
    full_name = false,
    indent_markers = { enable = true },
    icons = {
      show = { file = true, folder = true, folder_arrow = true, git = false },
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
map('n', '<leader>e', api.tree.toggle,
  { desc = 'Toggle file explorer (nvim-tree)', nowait = true })
map('n', '<leader>E', function()
  api.tree.find_file({ open = true, focus = true })
end, { desc = 'Reveal current file in explorer', nowait = true })

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
  end,
})
