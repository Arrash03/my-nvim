-- Indentation policy: literal tabs by default; explicit space exceptions.
local failures = 0
local function check(name, ok, detail)
  print(string.format('%s %s%s', ok and 'ok  ' or 'FAIL', name,
    detail and (' -- ' .. tostring(detail)) or ''))
  if not ok then failures = failures + 1 end
end

local function fresh_buffer(filetype)
  vim.cmd('enew!')
  vim.bo.buftype = 'nofile'
  vim.cmd('setfiletype ' .. filetype)
end

local function options_for(filetype)
  fresh_buffer(filetype)
  local b = vim.bo
  return {
    expandtab = b.expandtab,
    shiftwidth = b.shiftwidth,
    tabstop = b.tabstop,
    softtabstop = b.softtabstop,
    smartindent = b.smartindent,
  }
end

-- Anything not explicitly exempted uses literal tabs.
local def = options_for('text')
check('default: noexpandtab', def.expandtab == false, tostring(def.expandtab))
check('default: softtabstop 0 (literal tab)', def.softtabstop == 0,
  tostring(def.softtabstop))

for _, ft in ipairs({ 'c', 'cpp', 'rust', 'cmake' }) do
  local o = options_for(ft)
  check(ft .. ': noexpandtab', o.expandtab == false, tostring(o.expandtab))
  check(ft .. ': tabstop/shiftwidth 4',
    o.tabstop == 4 and o.shiftwidth == 4,
    'tabstop=' .. o.tabstop .. ' shiftwidth=' .. o.shiftwidth)
  check(ft .. ': softtabstop 0 (literal tab)', o.softtabstop == 0,
    tostring(o.softtabstop))
end

local py = options_for('python')
check('python: expandtab', py.expandtab == true, tostring(py.expandtab))
check('python: 4 spaces', py.tabstop == 4 and py.shiftwidth == 4
  and py.softtabstop == 4,
  'ts=' .. py.tabstop .. ' sw=' .. py.shiftwidth .. ' sts=' .. py.softtabstop)

local lua = options_for('lua')
check('lua: expandtab', lua.expandtab == true, tostring(lua.expandtab))
check('lua: 2 spaces', lua.tabstop == 2 and lua.shiftwidth == 2
  and lua.softtabstop == 2,
  'ts=' .. lua.tabstop .. ' sw=' .. lua.shiftwidth .. ' sts=' .. lua.softtabstop)

local md = options_for('markdown')
check('markdown: expandtab', md.expandtab == true, tostring(md.expandtab))
check('markdown: 2 spaces', md.tabstop == 2 and md.shiftwidth == 2
  and md.softtabstop == 2,
  'ts=' .. md.tabstop .. ' sw=' .. md.shiftwidth .. ' sts=' .. md.softtabstop)

-- Pressing Tab must insert the actual character, not just set options.
local function tab_insert(filetype)
  fresh_buffer(filetype)
  vim.api.nvim_feedkeys('i\t', 'x', false)
  return vim.api.nvim_get_current_line()
end

for _, ft in ipairs({ 'c', 'cpp', 'rust', 'cmake' }) do
  local line = tab_insert(ft)
  check(ft .. ': Tab inserts a tab', line == '\t',
    string.format('%q', line))
end
local py_line = tab_insert('python')
check('python: Tab inserts four spaces', py_line == '    ',
  string.format('%q', py_line))

local def_line = tab_insert('text')
check('default: Tab inserts a tab', def_line == '\t',
  string.format('%q', def_line))
local lua_line = tab_insert('lua')
check('lua: Tab inserts two spaces', lua_line == '  ',
  string.format('%q', lua_line))
local md_line = tab_insert('markdown')
check('markdown: Tab inserts two spaces', md_line == '  ',
  string.format('%q', md_line))

-- CMakeLists.txt is detected as cmake and therefore uses tabs too.
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, 'p')
local cmake_file = dir .. '/CMakeLists.txt'
vim.fn.writefile({ 'cmake_minimum_required(VERSION 3.20)' }, cmake_file)
vim.cmd('edit ' .. vim.fn.fnameescape(cmake_file))
check('CMakeLists.txt detected as cmake', vim.bo.filetype == 'cmake',
  vim.bo.filetype)
check('CMakeLists.txt uses tabs', vim.bo.expandtab == false,
  tostring(vim.bo.expandtab))

if failures == 0 then
  print('NVF-INDENT-OK')
else
  print('NVF-INDENT-FAIL ' .. failures)
  vim.cmd('cquit 1')
end
vim.cmd('qa!')
