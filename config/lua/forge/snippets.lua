--[[
  Snippets: LuaSnip + the friendly-snippets collection (shipped inside
  the package, loaded from disk) + a small set of nvim-forge originals
  for Python, C, C++ and Rust.
]]

local luasnip = require('luasnip')
local loader = require('luasnip.loaders.from_vscode')

luasnip.config.setup({
  history = false,
  updateevents = 'TextChanged,TextChangedI',
  enable_autosnippets = false,
})

-- friendly-snippets: bundled VSCode-style snippets (no npm involved).
local forge_home = _G.NVFORGE_HOME
loader.lazy_load({
  paths = { forge_home .. '/plugins/friendly-snippets' },
})

-- nvim-forge original snippets (Lua format, one file per language).
local ok, forge_snippets = pcall(require, 'forge.snippets_ext')
if ok then
  forge_snippets.load(luasnip)
end
