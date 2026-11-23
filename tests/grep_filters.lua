-- Include/exclude filters for text search, using the offline grep fallback.
local failures = 0
local function check(name, ok, detail)
  print(string.format('%s %s%s', ok and 'ok  ' or 'FAIL', name,
    detail and (' -- ' .. tostring(detail)) or ''))
  if not ok then failures = failures + 1 end
end

local picker = require('forge.picker')

check('mapping <leader>fG defined', vim.fn.maparg('<leader>fG', 'n') ~= '')

local cmd = picker.build_grep_command('needle', { '*.py' },
  { 'skip.py', 'vendor/' })
local joined = table.concat(cmd, ' ')
check('grep --include is built', joined:find('%-%-include=%*%.py') ~= nil,
  joined)
check('grep --exclude is built', joined:find('%-%-exclude=skip%.py') ~= nil,
  joined)
check('grep --exclude-dir is built',
  joined:find('%-%-exclude%-dir=vendor') ~= nil, joined)
check('grep pattern is protected by --', joined:find('%-%- needle %.') ~= nil,
  joined)

local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/vendor', 'p')
vim.fn.writefile({ 'needle keep' }, root .. '/keep.py')
vim.fn.writefile({ 'needle skip' }, root .. '/skip.py')
vim.fn.writefile({ 'needle c file' }, root .. '/keep.c')
vim.fn.writefile({ 'needle notes' }, root .. '/notes.txt')
vim.fn.writefile({ 'needle vendor' }, root .. '/vendor/hidden.py')
vim.fn.chdir(root)

picker.grep_with_filters({
  pattern = 'needle',
  include = { '*.py' },
  exclude = { 'skip.py', 'vendor/' },
  force_grep = true,
})

local matches = vim.fn.getqflist()
check('filtered grep returns one match', #matches == 1,
  'entries=' .. #matches)
if #matches == 1 then
  local entry = matches[1]
  local name = entry.filename
  if (not name or name == '') and entry.bufnr and entry.bufnr ~= 0 then
    name = vim.api.nvim_buf_get_name(entry.bufnr)
  end
  check('filtered grep kept only keep.py',
    vim.fn.fnamemodify(name or '', ':t') == 'keep.py', name)
end

picker.grep_with_filters({
  pattern = 'needle',
  include = '*.c',
  exclude = 'keep.c',
  force_grep = true,
})
check('include + exclude can yield no matches', #vim.fn.getqflist() == 0,
  'entries=' .. #vim.fn.getqflist())

if failures == 0 then
  print('NVF-GREP-FILTERS-OK')
else
  print('NVF-GREP-FILTERS-FAIL ' .. failures)
  vim.cmd('cquit 1')
end
vim.cmd('qa!')
