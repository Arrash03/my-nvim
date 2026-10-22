--[[
  Headless startup smoke test for nvim-forge.

  Run as:  nvim-forge --headless -c 'luafile /nvf-build/tests/startup.lua'
  Exits 0 and prints NVF-STARTUP-OK when the whole distribution comes up
  correctly; exits 1 with NVF-STARTUP-FAIL otherwise.
]]

local failures = {}
local function check(name, ok, detail)
  if ok then
    print(string.format('  ok   %s', name))
  else
    local msg = string.format('  FAIL %s%s', name,
      detail and (' -- ' .. tostring(detail)) or '')
    print(msg)
    failures[#failures + 1] = msg
  end
end

print('[nvf startup test]')

-- Leader + options --------------------------------------------------------
check('mapleader is <Space>', vim.g.mapleader == ' ', vim.g.mapleader)
check('number', vim.o.number == true)
check('relativenumber', vim.o.relativenumber == true)
check('signcolumn=yes', vim.o.signcolumn == 'yes')
check('termguicolors', vim.o.termguicolors == true)
check('updatetime sane', vim.o.updatetime > 0 and vim.o.updatetime <= 500,
  vim.o.updatetime)

-- Theme -------------------------------------------------------------------
check('colorscheme = forge', vim.g.colors_name == 'forge', vim.g.colors_name)
local bg = vim.api.nvim_get_hl(0, { name = 'Normal', link = false }).bg
local function to_hex(c)
  return c and string.format('#%06x', c) or 'nil'
end
-- Kanagawa Dragon-derived near-black background (#0D0F12-ish, never neon).
local bg_hex = bg and string.format('%06x', bg):upper() or ''
check('Normal.bg is a dark background (>= #0A0A0A, <= #1E2228)',
  bg ~= nil and bg >= 0x0A0A0A and bg <= 0x1E2228, to_hex(bg))

-- Plugins on runtimepath and loadable ------------------------------------
local rtp = table.concat(vim.opt.runtimepath:get(), ',')
for _, p in ipairs({ 'nvim-treesitter', 'nvim-lspconfig', 'nvim-cmp',
                     'LuaSnip', 'lualine.nvim', 'nvim-autopairs',
                     'telescope.nvim', 'plenary.nvim', 'nvim-tree.lua',
                     'nvim-web-devicons' }) do
  check('runtimepath has ' .. p, rtp:find('/plugins/' .. p, 1, true) ~= nil)
end

local mods = {
  { 'cmp', 'nvim-cmp' },
  { 'luasnip', 'LuaSnip' },
  { 'telescope', 'telescope.nvim' },
  { 'lualine', 'lualine.nvim' },
  { 'nvim-treesitter', 'nvim-treesitter' },
  { 'nvim-autopairs', 'nvim-autopairs' },
  { 'cmp_nvim_lsp', 'cmp-nvim-lsp' },
}
for _, m in ipairs(mods) do
  local ok, err = pcall(require, m[1])
  check('require("' .. m[1] .. '") from ' .. m[2], ok, err)
end

-- File explorer (nvim-tree) ----------------------------------------------
do
  local nt_ok, nt_api = pcall(require, 'nvim-tree.api')
  check('require("nvim-tree.api")', nt_ok, nt_api)
  if nt_ok then
    local function tree_win_open()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == 'NvimTree' then
          return true
        end
      end
      return false
    end
    local e1, e2 = pcall(nt_api.tree.open)
    check('explorer opens (NvimTree window present)', e1 and tree_win_open(), e2)
    local c1, c2 = pcall(nt_api.tree.close)
    check('explorer closes (NvimTree window gone)', c1 and not tree_win_open(), c2)
    local t1, t2 = pcall(nt_api.tree.toggle)
    check('explorer toggles', t1 and tree_win_open(), t2)
    pcall(nt_api.tree.close)
  end
end

-- LSP plumbing ------------------------------------------------------------
check('vim.lsp.config API present',
  type(vim.lsp.config) == 'table' or type(vim.lsp.config) == 'function')
check('vim.lsp.enable API present', type(vim.lsp.enable) == 'function')
for _, name in ipairs({ 'basedpyright', 'clangd', 'rust_analyzer' }) do
  local ok = pcall(function()
    local cfg = vim.lsp.config[name]
    assert(cfg, 'no config for ' .. name)
  end)
  check('lsp config registered: ' .. name, ok)
end

-- Bundled executables -----------------------------------------------------
local exe = {
  { '/bin/nvim', 'Neovim' },
  { '/lib/node/bin/node', 'Node.js runtime' },
  { '/servers/clangd/bin/clangd', 'clangd' },
  { '/lib/rust/bin/rust-analyzer', 'rust-analyzer' },
  { '/lib/rust/bin/rustc', 'rustc' },
  { '/lib/rust/bin/cargo', 'cargo' },
}
local home = _G.NVFORGE_HOME or vim.env.NVF_HOME or '/opt/nvim-forge'
for _, e in ipairs(exe) do
  check(e[2] .. ' present + executable',
    vim.fn.executable(home .. e[1]) == 1, home .. e[1])
end

-- Tree-sitter parsers -----------------------------------------------------
for _, lang in ipairs({ 'python', 'c', 'cpp', 'rust' }) do
  local files = vim.api.nvim_get_runtime_file('parser/' .. lang .. '.so', true)
  check('parser ' .. lang .. '.so on runtimepath', #files > 0)
  if #files > 0 then
    local ok, err = pcall(vim.treesitter.language.add, lang)
    check('treesitter loads ' .. lang, ok, err)
  end
end

-- Help tags ---------------------------------------------------------------
check('helptags generated (:help lspconfig works offline)',
  vim.fn.filereadable(home .. '/plugins/nvim-lspconfig/doc/tags') == 1)

if #failures == 0 then
  print('NVF-STARTUP-OK')
  vim.cmd('qa!')
else
  print('NVF-STARTUP-FAIL (' .. #failures .. ' failures)')
  vim.cmd('cquit 1')
end
