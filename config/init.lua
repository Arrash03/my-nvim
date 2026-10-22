--[[
  nvim-forge init.lua
  -------------------
  Entry point of the nvim-forge distribution.  It is passed to the bundled
  Neovim with `-u` by /usr/bin/nvim-forge, so the user's own ~/.config/nvim
  is never touched and nvim-forge is fully isolated from it.

  Design notes:
    * The whole bundle lives under $NVF_HOME (/opt/nvim-forge by default).
      The launcher exports NVF_HOME; if unset we derive it from our own
      file location so that the config also works when invoked manually.
    * Plugins are *vendored directories* on the runtimepath.  There is no
      plugin manager, no bootstrap step and no network access at startup:
      Neovim's own plugin loading phase sources each vendored plugin's
      plugin/ scripts after init.lua finishes.  This is deliberate --
      lazy.nvim was rejected because it requires `git` and tries to
      install missing plugins on first start, which violates the offline
      self-containment requirement.
    * Writable per-user data (shada, swap, undo, cache, logs) goes through
      stdpath(), which the launcher redirects under NVIM_APPNAME=nvim-forge,
      i.e. ~/.local/{state,share}/nvim-forge and ~/.cache/nvim-forge.
]]

-- Leader key must be set before any plugin loads.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Resolve bundle locations -------------------------------------------------
local this = debug.getinfo(1, 'S').source:sub(2)
local config_dir = vim.fs.normalize(vim.fn.fnamemodify(this, ':p:h'))
local forge_home = vim.env.NVF_HOME or vim.fs.normalize(config_dir .. '/..')
vim.env.NVF_HOME = forge_home
_G.NVFORGE_HOME = forge_home

-- Make our config (colors/, lsp/, lua/, snippets/) take priority over any
-- other runtimepath entry with the same files.
vim.opt.runtimepath:prepend(config_dir)

-- Vendor-bundled plugins: plain directories added to the runtimepath in
-- deterministic (sorted) order.  Nothing here downloads or updates itself.
local plugins_dir = forge_home .. '/plugins'
local names = {}
for name in vim.fs.dir(plugins_dir) do
  names[#names + 1] = name
end
table.sort(names)
for i = #names, 1, -1 do
  vim.opt.runtimepath:prepend(plugins_dir .. '/' .. names[i])
end

-- Core modules (each is a small, self-contained Lua module) ---------------
require('forge.options')
require('forge.keymaps')
require('forge.autocmds')
require('forge.treesitter')   -- bundled parsers + highlight/indent wiring
require('forge.statusline')   -- lualine with the forge theme
require('forge.picker')       -- telescope (+ rg-free grep fallback)
require('forge.explorer')     -- nvim-tree sidebar file explorer (<leader>e)
require('forge.snippets')     -- LuaSnip + friendly-snippets + own snippets
require('forge.cmp')          -- nvim-cmp completion
require('forge.lsp')          -- native vim.lsp.config/enable + diagnostics

-- Theme last so nothing overrides it.
vim.cmd.colorscheme('forge')
