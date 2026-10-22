--[[
  Global key mappings.  LSP-specific mappings are buffer-local and set on
  LspAttach in forge.lsp; picker mappings live in forge.picker.
  Leader is <Space> (set in init.lua before any plugin loads).
]]

local map = vim.keymap.set
local opts = { silent = true }

-- Clear search highlight ---------------------------------------------------
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })

-- Save / quit --------------------------------------------------------------
map('n', '<leader>w', '<cmd>write<CR>', { desc = 'Save file' })
map('n', '<leader>q', '<cmd>quit<CR>', { desc = 'Quit' })
map('n', '<leader>W', '<cmd>wall<CR>', { desc = 'Save all' })
map('n', '<leader>Q', '<cmd>qall<CR>', { desc = 'Quit all' })

-- Window navigation --------------------------------------------------------
map('n', '<C-h>', '<C-w>h', { desc = 'Window left' })
map('n', '<C-j>', '<C-w>j', { desc = 'Window down' })
map('n', '<C-k>', '<C-w>k', { desc = 'Window up' })
map('n', '<C-l>', '<C-w>l', { desc = 'Window right' })

-- Buffers ------------------------------------------------------------------
map('n', '[b', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
map('n', ']b', '<cmd>bnext<CR>', { desc = 'Next buffer' })

-- Move selected lines ------------------------------------------------------
map('v', 'J', ":m '>+1<CR>gv=gv", opts)
map('v', 'K', ":m '<-2<CR>gv=gv", opts)

-- Keep cursor centered while paging ----------------------------------------
map('n', '<C-d>', '<C-d>zz', opts)
map('n', '<C-u>', '<C-u>zz', opts)
map('n', 'n', 'nzzzv', opts)
map('n', 'N', 'Nzzzv', opts)

-- Diagnostics (global fallbacks; buffer-local versions added on attach) ----
map('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end,
  { desc = 'Previous diagnostic' })
map('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end,
  { desc = 'Next diagnostic' })
map('n', '<leader>d', vim.diagnostic.open_float,
  { desc = 'Show diagnostic details' })
map('n', '<leader>dl', vim.diagnostic.setloclist,
  { desc = 'Diagnostics to location list' })

-- Quickfix -----------------------------------------------------------------
map('n', '[q', '<cmd>cprevious<CR>zz', { desc = 'Previous quickfix entry' })
map('n', ']q', '<cmd>cnext<CR>zz', { desc = 'Next quickfix entry' })

-- Terminal -----------------------------------------------------------------
map('t', '<Esc><Esc>', [[<C-\><C-n>]], { desc = 'Terminal normal mode' })
