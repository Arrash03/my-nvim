-- Command-line (`:`) suggestion settings.
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

check('wildmenu enabled', vim.o.wildmenu == true, tostring(vim.o.wildmenu))
check('wildchar is <Tab>', vim.o.wildchar == 9, tostring(vim.o.wildchar))
check('wildmode lists matches first',
  vim.o.wildmode:find('list', 1, true) ~= nil
    and vim.o.wildmode:find('longest', 1, true) ~= nil,
  vim.o.wildmode)
check('wildmode completes fully on next Tab',
  vim.o.wildmode:find('full', 1, true) ~= nil, vim.o.wildmode)
check('wildoptions uses popup menu',
  vim.o.wildoptions:find('pum', 1, true) ~= nil, vim.o.wildoptions)
check('wildignorecase enabled', vim.o.wildignorecase == true,
  tostring(vim.o.wildignorecase))
check('wildignore skips noisy directories',
  vim.o.wildignore ~= '', tostring(vim.o.wildignore))

-- The candidate source used by the popup must include our user commands.
local cmds = vim.fn.getcompletion('NVF', 'cmdline')
check('command suggestions include :NVFCompileDB', has(cmds, 'NVFCompileDB'),
  table.concat(cmds, ','))
check('command suggestions include :NVFGitChanges', has(cmds, 'NVFGitChanges'),
  table.concat(cmds, ','))

-- File-name completion should also produce real candidates.
local probe = 'README-cmdline-probe.md'
vim.fn.writefile({ 'probe' }, probe)
local files = vim.fn.getcompletion('README-cmdline-probe', 'file')
check('file suggestions are available', #files > 0, table.concat(files, ','))
vim.fn.delete(probe)

if failures == 0 then
  print('NVF-CMDLINE-OK')
else
  print('NVF-CMDLINE-FAIL ' .. failures)
  vim.cmd('cquit 1')
end
vim.cmd('qa!')
