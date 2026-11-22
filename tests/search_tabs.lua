-- Search-result tabs: Telescope and the offline grep/quickfix fallback must
-- both be able to open the selected match in a new tab.
local failures = 0
local function check(name, ok, detail)
  print(string.format('%s %s%s', ok and 'ok  ' or 'FAIL', name,
    detail and (' -- ' .. tostring(detail)) or ''))
  if not ok then failures = failures + 1 end
end

local function name_of(buf)
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':p')
end

local telescope = require('telescope.config').values
check('telescope <C-t> insert mapping',
  telescope.mappings.i['<C-t>'] ~= nil)
check('telescope <C-t> normal mapping',
  telescope.mappings.n and telescope.mappings.n['<C-t>'] ~= nil)

local first = vim.fn.tempname() .. '.txt'
local second = vim.fn.tempname() .. '.txt'
vim.fn.writefile({ 'context line', 'first match' }, first)
vim.fn.writefile({ 'second match' }, second)

-- Quickfix path (used by <leader>fg without rg, <leader>gc, references...).
vim.fn.setqflist({
  { filename = first, lnum = 2, col = 3, text = 'first match' },
  { filename = second, lnum = 1, col = 1, text = 'second match' },
})
vim.cmd('copen')
check('quickfix <C-t> mapped', vim.fn.maparg('<C-t>', 'n') ~= '')
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-t>', true, false, true),
  'x', false)
check('quickfix opened new tab', vim.fn.tabpagenr('$') == 2,
  'tabs=' .. vim.fn.tabpagenr('$'))
check('quickfix tab shows first match', name_of(0) == vim.fn.fnamemodify(first, ':p'),
  name_of(0))
local cursor = vim.api.nvim_win_get_cursor(0)
check('quickfix tab jumps to match', cursor[1] == 2 and cursor[2] == 2,
  vim.inspect(cursor))

-- Location-list path (diagnostics, :lgrep-style lists).
vim.cmd('tabclose')
vim.cmd('edit ' .. vim.fn.fnameescape(first))
vim.fn.setloclist(0, {
  { filename = second, lnum = 1, col = 1, text = 'location match' },
})
vim.cmd('lopen')
check('location list <C-t> mapped', vim.fn.maparg('<C-t>', 'n') ~= '')
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-t>', true, false, true),
  'x', false)
check('location list opened new tab', vim.fn.tabpagenr('$') == 2,
  'tabs=' .. vim.fn.tabpagenr('$'))
check('location-list tab shows match', name_of(0) == vim.fn.fnamemodify(second, ':p'),
  name_of(0))

if failures == 0 then
  print('NVF-SEARCH-TABS-OK')
else
  print('NVF-SEARCH-TABS-FAIL ' .. failures)
  vim.cmd('cquit 1')
end
vim.cmd('qa!')
