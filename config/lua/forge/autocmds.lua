--[[
  Autocommands: filetype-specific indentation, yank highlight,
  large-file protection and per-filetype treesitter wiring.
]]

local augroup = function(name)
  return vim.api.nvim_create_augroup('nvf_' .. name, { clear = true })
end

-- Indentation policy --------------------------------------------------------
-- Python, C, C++ and Rust: 4 spaces, expanded tabs (per distribution spec).
-- Lua (our own config): 2 spaces, the ecosystem convention.
vim.api.nvim_create_autocmd('FileType', {
  group = augroup('indent'),
  pattern = { 'python', 'c', 'cpp', 'rust' },
  callback = function(ev)
    vim.bo[ev.buf].expandtab = true
    vim.bo[ev.buf].shiftwidth = 4
    vim.bo[ev.buf].tabstop = 4
    vim.bo[ev.buf].softtabstop = 4
    vim.bo[ev.buf].smartindent = true
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  group = augroup('indent_lua'),
  pattern = 'lua',
  callback = function(ev)
    vim.bo[ev.buf].shiftwidth = 2
    vim.bo[ev.buf].tabstop = 2
    vim.bo[ev.buf].softtabstop = 2
  end,
})

-- Highlight yanked text -----------------------------------------------------
vim.api.nvim_create_autocmd('TextYankPost', {
  group = augroup('yank'),
  callback = function()
    vim.highlight.on_yank({ higroup = 'IncSearch', timeout = 150 })
  end,
})

-- Restore cursor position ---------------------------------------------------
vim.api.nvim_create_autocmd('BufReadPost', {
  group = augroup('restore_cursor'),
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Large files: skip expensive features above 2 MiB --------------------------
vim.api.nvim_create_autocmd('BufReadPre', {
  group = augroup('largefile'),
  callback = function(ev)
    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ev.buf))
    if ok and stats and stats.size > 2 * 1024 * 1024 then
      vim.b[ev.buf].largefile = true
      vim.bo[ev.buf].swapfile = false
      vim.bo[ev.buf].undofile = false
      vim.bo[ev.buf].syntax = 'OFF'   -- no regex syntax; treesitter also off
      vim.notify('nvim-forge: large file mode (no syntax/LSP)', vim.log.levels.INFO)
    end
  end,
})

-- Never start LSP on large files --------------------------------------------
-- (servers are only enabled for real code filetypes; this is a hard stop)

-- Close LSP floats on press Escape (nvim 0.11+: float windows) -------------
vim.api.nvim_create_autocmd('FileType', {
  group = augroup('float_keys'),
  pattern = { 'lspinfo', 'qf', 'help', 'man' },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = ev.buf, silent = true })
  end,
})

-- Diagnostics: don't open floats while typing ------------------------------
vim.diagnostic.config({
  update_in_insert = false,
  severity_sort = true,
})
