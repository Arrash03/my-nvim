-- Behavioral test for nvim-cmp autocomplete / suggestions.
-- Headless Neovim cannot hold insert mode, so this verifies the configured
-- sources/mappings and drives the buffer source directly with a real prefix.
local failures = 0
local function check(name, ok, detail)
  print(string.format('%s %s%s', ok and 'ok  ' or 'FAIL', name,
    detail and (' -- ' .. tostring(detail)) or ''))
  if not ok then failures = failures + 1 end
end

local function has(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

local cmp = require('cmp')
local cfg = cmp.get_config()
check('autocompletion enabled', cfg.completion.autocompletion == true,
  tostring(cfg.completion.autocompletion))

local sources = {}
for _, src in ipairs(cfg.sources or {}) do sources[#sources + 1] = src.name end
check('LSP completion source', has(sources, 'nvim_lsp'), table.concat(sources, ','))
check('snippet completion source', has(sources, 'luasnip'))
check('buffer completion source', has(sources, 'buffer'))
check('explicit <C-Space> mapping', cfg.mapping and cfg.mapping['<C-Space>'] ~= nil)
check('Enter accept mapping', cfg.mapping and cfg.mapping['<CR>'] ~= nil)

-- Drive the buffer source directly: a partial word must produce a real
-- suggestion that cmp can insert.  This is the same code path used while
-- typing, without needing a terminal UI.
local buffer_source = require('cmp_buffer')
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha_beta_gamma = 1', 'alph' })
local done, items = false, {}
buffer_source:complete({
  option = { keyword_length = 2 },
  context = { cursor_before_line = 'alph' },
  offset = 1,
}, function(response)
  items = response and response.items or {}
  done = true
end)
vim.wait(3000, function() return done end, 50)
check('buffer source completed', done)
local words = {}
for _, item in ipairs(items) do words[#words + 1] = item.word or item.label or '' end
check('partial word suggests full identifier', has(words, 'alpha_beta_gamma'),
  table.concat(words, ','))

if failures == 0 then
  print('NVF-COMPLETION-OK')
else
  print('NVF-COMPLETION-FAIL ' .. failures)
  vim.cmd('cquit 1')
end
vim.cmd('qa!')
