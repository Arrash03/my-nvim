-- Acceptance test for optional Git Lens / blame support.
-- Runs with tests/fake-git first on PATH, so no real git repo is required.
local failures = 0
local function check(name, ok, detail)
  print(string.format('%s %s%s', ok and 'ok  ' or 'FAIL', name,
    detail and (' -- ' .. tostring(detail)) or ''))
  if not ok then failures = failures + 1 end
end

local git = require('forge.git')
check('git executable found (stub)', git.state().git)

for _, cmd in ipairs({ 'NVFGitChanges', 'NVFGitBlame', 'NVFGitRefresh' }) do
  check('command :' .. cmd, vim.fn.exists(':' .. cmd) == 2)
end
for _, key in ipairs({ '<leader>gc', '<leader>gb', '<leader>gR', '[g', ']g' }) do
  check('mapping ' .. key, vim.fn.maparg(key, 'n') ~= '')
end

vim.wait(5000, function() return git.state().signs >= 3 end, 100)
local s = git.state()
check('change signs placed', s.signs >= 3, s.signs)
check('deleted line marked', s.changed[1] == 'delete', tostring(s.changed[1]))
check('added lines marked',
  s.changed[2] == 'add' and s.changed[4] == 'add',
  tostring(s.changed[2]) .. ',' .. tostring(s.changed[4]))

vim.cmd('NVFGitBlame')
vim.wait(5000, function() return git.state().blame >= 4 end, 100)
s = git.state()
check('inline blame virtual text placed', s.blame >= 4, s.blame)
check('blame shows author', s.sample:find('Alice', 1, true) ~= nil, s.sample)

vim.cmd('NVFGitChanges')
vim.wait(3000, function() return vim.fn.getqflist({ size = 0 }).size == 2 end, 100)
local qf = vim.fn.getqflist()
check('two changed files in quickfix', #qf == 2, #qf)
local texts = {}
for _, e in ipairs(qf) do texts[#texts + 1] = e.text end
check('modified + untracked reported',
  table.concat(texts, '|'):find('modified', 1, true) ~= nil
    and table.concat(texts, '|'):find('untracked', 1, true) ~= nil,
  table.concat(texts, '|'))

-- Return to the source buffer and jump between changed lines.
vim.cmd('cclose')
vim.cmd('buffer ' .. vim.fn.bufnr('main.c'))
vim.wait(3000, function() return git.state().signs >= 3 end, 100)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
git.jump_changed(1)
check(']g jumps to next changed line', vim.fn.line('.') == 2, vim.fn.line('.'))
git.jump_changed(1)
check(']g wraps / advances', vim.fn.line('.') == 4, vim.fn.line('.'))

if failures == 0 then
  print('NVF-GIT-OK')
else
  print('NVF-GIT-FAIL ' .. failures)
  vim.cmd('cquit 1')
end
for _, c in ipairs(vim.lsp.get_clients()) do pcall(function() c:stop(true) end) end
vim.cmd('qa!')
