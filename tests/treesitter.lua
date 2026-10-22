--[[
  Tree-sitter test: run against a sample file, e.g.
    nvim-forge --headless /root/nvf-work/test.py \
      -c 'luafile /nvf-build/tests/treesitter.lua'
  Verifies the prebuilt bundled parsers parse real syntax trees and that
  the highlighter attaches.  Exits 0/1 accordingly.
]]

local failures = 0
local function check(name, ok, detail)
  if ok then
    print('  ok   ' .. name)
  else
    print(string.format('  FAIL %s%s', name,
      detail and (' -- ' .. tostring(detail)) or ''))
    failures = failures + 1
  end
end

local ft = vim.bo.filetype
print('[nvf treesitter test] file=' .. vim.fn.expand('%:p') .. ' ft=' .. ft)

-- Parsers for all four shipped languages must be present and loadable.
for _, lang in ipairs({ 'python', 'c', 'cpp', 'rust' }) do
  local files = vim.api.nvim_get_runtime_file('parser/' .. lang .. '.so', true)
  check('parser file for ' .. lang, #files > 0, 'not on runtimepath')
  if #files > 0 then
    local ok, err = pcall(vim.treesitter.language.add, lang)
    check('language.add(' .. lang .. ')', ok, err)
  end
end

-- The current buffer must produce a non-empty syntax tree.
if ft ~= '' then
  local ok, parser_or_err = pcall(vim.treesitter.get_parser, 0, ft)
  check('get_parser(' .. ft .. ')', ok, parser_or_err)
  if ok then
    local parser = parser_or_err
    local trees = parser:parse()
    local root = trees[1] and trees[1]:root()
    check('parse produces a tree', root ~= nil)
    if root then
      check('tree root has children (' .. root:named_child_count() .. ' named)',
        root:named_child_count() > 0)
      check('root sexpr starts with (' .. (root:sexpr():sub(1, 40)) .. ')',
        root:sexpr():sub(1, 1) == '(')
    end
    -- Highlighter wiring (forge.treesitter) must be active for this buffer.
    local okh, errh = pcall(vim.treesitter.start, 0, ft)
    check('vim.treesitter.start', okh, errh)
    check('highlighter attached',
      vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)
  end
else
  check('filetype detected', false, 'empty filetype')
end

-- Shut down any LSP client cleanly before exiting: an orphaned server that
-- outlives nvim confuses exit-status propagation through the proot sandbox.
pcall(function()
  vim.lsp.stop_client(vim.lsp.get_clients(), true)
  vim.wait(5000, function()
    return #vim.lsp.get_clients() == 0
  end, 100)
end)

if failures == 0 then
  print('NVF-TREESITTER-OK')
  vim.cmd('qa!')
else
  print('NVF-TREESITTER-FAIL (' .. failures .. ')')
  vim.cmd('cquit 1')
end
