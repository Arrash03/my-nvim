--[[
  LSP attach test for nvim-forge.

  The first file on the command line has already been read when -c runs, so
  vim.lsp.enable() has already fired for its filetype.  This script waits
  (bounded) for the expected server to attach, then exits 0/1.

  Environment:
    NVF_TEST_SERVER   expected client name (basedpyright|clangd|rust_analyzer)
    NVF_TEST_TIMEOUT  max wait in ms (default 45000)

  Prints NVF-LSP-OK <client> <pid> or NVF-LSP-FAIL <detail>.
]]

local expected = vim.env.NVF_TEST_SERVER or ''
local timeout = tonumber(vim.env.NVF_TEST_TIMEOUT or '45000') or 45000

local function client_names()
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients()) do
    names[#names + 1] = c.name
  end
  return table.concat(names, ',')
end

print(string.format('[nvf lsp test] file=%s expecting=%s',
  vim.fn.expand('%:p'), expected))

local attached = nil
local ok = vim.wait(timeout, function()
  for _, c in ipairs(vim.lsp.get_clients()) do
    if c.name == expected then
      attached = c
      return true
    end
  end
  return false
end, 250)

if not ok or not attached then
  print('NVF-LSP-FAIL timeout after ' .. timeout .. 'ms; clients=['
    .. client_names() .. ']')
  -- Surface server logs to help diagnosis.
  local log = vim.fn.stdpath('state') .. '/lsp.log'
  if vim.fn.filereadable(log) == 1 then
    local lines = vim.fn.readfile(log)
    for i = math.max(1, #lines - 15), #lines do
      print('  lsp.log: ' .. lines[i])
    end
  end
  vim.cmd('cquit 1')
end

-- Sanity: server-side capabilities actually usable.
local caps = attached.server_capabilities or {}
print(string.format('NVF-LSP-OK client=%s pid=%d root=%s',
  attached.name, attached.id,
  tostring(attached.root_dir or attached.config.root_dir or 'nil')))
print('  completionProvider=' ..
  tostring(caps.textDocumentSync ~= nil))
print('  definitionProvider=' ..
  tostring(caps.definitionProvider ~= nil))

-- Buffer-local keymaps from the LspAttach autocmd must be present (the
-- autocmd may run a tick after the client shows up, so wait briefly).
local function mapped(lhs)
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
    if m.lhs == lhs then
      return true
    end
  end
  return false
end
local maps_ok = vim.wait(5000, function()
  return mapped('gd') and mapped('gr') and mapped('K')
end, 100)
if not maps_ok then
  print('NVF-LSP-FAIL buffer keymaps gd/gr/K not bound after attach')
  vim.cmd('cquit 1')
end
print('  keymaps gd/gr/K bound on attach')

-- Clean shutdown so no server outlives nvim (keeps exit codes reliable).
pcall(function()
  vim.lsp.stop_client(attached.id, true)
  vim.wait(5000, function()
    return vim.lsp.get_client_by_id(attached.id) == nil
  end, 100)
end)

vim.cmd('qa!')
