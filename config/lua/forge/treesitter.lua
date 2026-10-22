--[[
  Tree-sitter wiring.

  Parsers for python, c, cpp and rust are pre-built and shipped in
  $NVF_HOME/parsers/parser/*.so; queries ship inside the vendored
  nvim-treesitter plugin (runtime/queries).  Nothing here downloads or
  compiles anything: :TSInstall is never invoked and auto-install is not
  configured.
]]

local forge_home = _G.NVFORGE_HOME

-- nvim-treesitter (main branch) manages only where parsers are looked up.
-- install_dir is inside the read-only bundle and pre-populated by packaging.
require('nvim-treesitter').setup({
  install_dir = forge_home .. '/parsers',
})

-- Languages for which we ship compiled parsers.
local TS_LANGUAGES = { 'python', 'c', 'cpp', 'rust' }

-- Enable treesitter highlight + indent for the supported filetypes only.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('nvf_treesitter', { clear = true }),
  pattern = TS_LANGUAGES,
  callback = function(ev)
    local buf = ev.buf
    if vim.b[buf].largefile then
      return
    end
    -- Parser must be loadable; guard so a missing parser can never break
    -- opening a file (e.g. unusual builds).
    local ok = pcall(vim.treesitter.language.add, ev.match)
    if not ok then
      return
    end
    pcall(vim.treesitter.start, buf, ev.match)
    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

-- Stop treesitter on buffers where it was started (e.g. :set ft=).
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('nvf_treesitter_stop', { clear = true }),
  callback = function(ev)
    local ft = ev.match
    local found = false
    for _, lang in ipairs(TS_LANGUAGES) do
      if lang == ft then
        found = true
        break
      end
    end
    if not found then
      pcall(vim.treesitter.stop, ev.buf)
    end
  end,
})

return { languages = TS_LANGUAGES }
