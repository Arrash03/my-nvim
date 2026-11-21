-- Verify that many files can be opened from nvim-tree, one tab per file.
-- Two modes, selected via NVF_TREE_TABS_MODE:
--   marks  : mark a.c/b.c/c.c with `m`, then <leader>tm
--   visual : select the three lines with V2j, then <C-t>
local mode = vim.env.NVF_TREE_TABS_MODE or 'marks'
local failures = 0
local function check(name, ok, detail)
  print(string.format('%s %s%s', ok and 'ok  ' or 'FAIL', name,
    detail and (' -- ' .. tostring(detail)) or ''))
  if not ok then failures = failures + 1 end
end

vim.wait(5000, function() return vim.bo.filetype == 'NvimTree' end, 50)
check('nvim-tree is current buffer', vim.bo.filetype == 'NvimTree', vim.bo.filetype)

local api = require('nvim-tree.api')
local explorer = require('nvim-tree.core').get_explorer()
local function line_of(name)
  for lnum = 1, 100 do
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    local node = explorer and explorer:get_node_at_cursor()
    if node and node.name == name then return lnum end
  end
  return nil
end

if mode == 'marks' then
  local nodes = explorer and explorer:get_nodes_in_range(1, 200) or {}
  local marked = 0
  for _, node in ipairs(nodes) do
    if node.type == 'file' and vim.tbl_contains({ 'a.c', 'b.c', 'c.c' }, node.name) then
      pcall(api.marks.toggle, node)
      marked = marked + 1
    end
  end
  check('marked three files', marked == 3, marked)
  local keys = vim.api.nvim_replace_termcodes(' tm', true, false, true)
  vim.api.nvim_feedkeys(keys, 'x', false)
else
  local first = line_of('a.c')
  check('found a.c in tree', first ~= nil, first)
  vim.api.nvim_win_set_cursor(0, { first or 1, 0 })
  local keys = vim.api.nvim_replace_termcodes('V2j<C-t>', true, false, true)
  vim.api.nvim_feedkeys(keys, 'x', false)
end

vim.wait(3000, function() return vim.fn.tabpagenr('$') >= 4 end, 50)
check('four tabs after batch open', vim.fn.tabpagenr('$') == 4, vim.fn.tabpagenr('$'))

local names = {}
for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
  local buf = vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(tabpage))
  table.insert(names, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t'))
end
check('tabs contain a.c/b.c/c.c',
  vim.tbl_contains(names, 'a.c') and vim.tbl_contains(names, 'b.c')
    and vim.tbl_contains(names, 'c.c'), table.concat(names, ','))

vim.cmd('tabfirst')
vim.cmd('normal gt')
check('gt still switches tab', vim.fn.tabpagenr() == 2, vim.fn.tabpagenr())

if failures == 0 then
  print('NVF-TREE-TABS-OK ' .. mode)
else
  print('NVF-TREE-TABS-FAIL ' .. mode .. ' ' .. failures)
end
for _, c in ipairs(vim.lsp.get_clients()) do pcall(function() c:stop(true) end) end
vim.cmd('qa!')
