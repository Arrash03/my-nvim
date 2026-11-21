--[[
  LSP: native Neovim LSP client (vim.lsp.config + vim.lsp.enable).

  Executable paths are absolute and point inside the bundle, so the
  servers work on a bare target system with no PATH setup and no
  user-level installs.

  nvim-lspconfig is vendored on the runtimepath: its lsp/<name>.lua
  runtime files provide battle-tested root markers, capabilities and
  buffer-local commands.  Calls to vim.lsp.config() here have the
  highest merge precedence (see :h vim.lsp.config), so the cmd/settings
  overrides below always win over the vendored defaults.
]]

local forge_home = _G.NVFORGE_HOME

-- Completion capabilities from nvim-cmp's LSP source ------------------------
local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_cmp, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
if ok_cmp then
  capabilities = cmp_lsp.default_capabilities(capabilities)
end

vim.lsp.config('*', {
  capabilities = capabilities,
})

-- Python: BasedPyright on the bundled Node.js runtime -----------------------
-- The server is pure JavaScript; node + langserver are absolute paths.
vim.lsp.config('basedpyright', {
  cmd = {
    forge_home .. '/lib/node/bin/node',
    forge_home .. '/servers/basedpyright/node_modules/basedpyright/langserver.index.js',
    '--stdio',
  },
  filetypes = { 'python' },
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = 'standard',
        autoSearchPaths = true,
        diagnosticMode = 'workspace',
      },
      disableTaggedHints = true,
    },
  },
})

-- C / C++: official LLVM clangd binary (statically linked libstdc++) --------
-- Ways to point clangd at compile_commands.json (no edits to this bundle):
--   1. put compile_commands.json in the project root (clangd searches upwards)
--   2. add a project `.clangd` file (enabled by --enable-config below):
--        CompileFlags:
--          CompilationDatabase: /absolute/path/to/build
--   3. export NVF_CLANGD_COMPILE_COMMANDS_DIR before launching nvim-forge, or
--      run :NVFCompileDB <dir> (<leader>cd) while editing to change it live.
local function clangd_cmd(compile_dir)
  local cmd = {
    forge_home .. '/servers/clangd/bin/clangd',
    '--background-index',
    '--clang-tidy',
    '--header-insertion=never',
    '--completion-style=detailed',
    '--fallback-style=LLVM',
    '--enable-config',  -- honour project .clangd files
    '-j=4',
  }
  if compile_dir and compile_dir ~= '' then
    table.insert(cmd, '--compile-commands-dir=' .. compile_dir)
  end
  return cmd
end

_G.NVF_CLANGD_COMPILE_DIR = vim.env.NVF_CLANGD_COMPILE_COMMANDS_DIR
vim.lsp.config('clangd', {
  cmd = clangd_cmd(_G.NVF_CLANGD_COMPILE_DIR),
  filetypes = { 'c', 'cpp' },
})

-- Rust: rust-analyzer + bundled toolchain ----------------------------------
-- rust-analyzer lives inside the bundled toolchain dir so that its
-- RUNPATH ($ORIGIN/../lib) finds librustc_driver; cargo/rustc come from the
-- launcher's PATH (/opt/nvim-forge/lib/rust/bin).  Std sources from the
-- rust-src component let RA jump into std:: code.
vim.lsp.config('rust_analyzer', {
  cmd = { forge_home .. '/lib/rust/bin/rust-analyzer' },
  filetypes = { 'rust' },
  settings = {
    ['rust-analyzer'] = {
      cargo = { allFeatures = false },  -- offline friendly
      inlayHints = {
        bindingModeHints = { enable = false },
        chainingHints = { enable = false },
        closingBraceHints = { enable = false },
        parameterHints = { enable = false },
        typeHints = { enable = true, hideRedundant = true },
        enumEntryHints = { enable = true },
      },
    },
  },
})

-- Enable the three bundled servers ------------------------------------------
vim.lsp.enable({ 'basedpyright', 'clangd', 'rust_analyzer' })

-- Runtime helpers: compile database + server restart ------------------------
vim.api.nvim_create_user_command('NVFCompileDB', function(info)
  local arg = vim.trim(info.args or '')
  if arg == '' then
    arg = vim.fn.input('compile_commands.json dir (or path to file): ',
      _G.NVF_CLANGD_COMPILE_DIR or '', 'file')
  end
  if arg == '' then
    return
  end
  arg = vim.fn.fnamemodify(arg, ':p')
  if vim.fn.isdirectory(arg) == 1 then
    if vim.fn.filereadable(arg .. '/compile_commands.json') ~= 1 then
      vim.notify('Warning: no compile_commands.json in ' .. arg,
        vim.log.levels.WARN, { title = 'nvim-forge' })
    end
  elseif vim.fn.filereadable(arg) == 1 and arg:match('compile_commands%.json$') then
    arg = vim.fn.fnamemodify(arg, ':h')
  else
    vim.notify('Invalid compile database path: ' .. arg,
      vim.log.levels.ERROR, { title = 'nvim-forge' })
    return
  end
  _G.NVF_CLANGD_COMPILE_DIR = arg
  local new_cmd = clangd_cmd(arg)
  vim.lsp.config('clangd', { cmd = new_cmd })
  -- `:lsp restart` reuses each client's config table, so update both the
  -- global config (for future clients) and any running clients before the
  -- restart; otherwise the old --compile-commands-dir would be reused.
  for _, client in ipairs(vim.lsp.get_clients({ name = 'clangd' })) do
    client.config.cmd = new_cmd
  end
  if #vim.lsp.get_clients({ name = 'clangd' }) > 0 then
    vim.cmd('lsp restart clangd')
    vim.notify('clangd restarted with compile database: ' .. arg,
      vim.log.levels.INFO, { title = 'nvim-forge' })
  else
    vim.notify('Compile database set to ' .. arg
      .. '; clangd will use it when you open a C/C++ file.',
      vim.log.levels.INFO, { title = 'nvim-forge' })
  end
end, {
  nargs = '?',
  desc = 'Set compile_commands.json directory for clangd and restart clangd',
  complete = 'dir',
})

-- Neovim 0.12 provides `:lsp restart [client]`; expose convenient keys.
vim.keymap.set('n', '<leader>cd', '<cmd>NVFCompileDB<CR>',
  { desc = 'Set clangd compile_commands.json directory' })
vim.keymap.set('n', '<leader>lr', '<cmd>lsp restart<CR>',
  { desc = 'Restart LSP clients attached to this buffer' })
vim.keymap.set('n', '<leader>lc', '<cmd>lsp restart clangd<CR>',
  { desc = 'Restart clangd' })
vim.keymap.set('n', '<leader>fi', function()
  local enabled = not vim.diagnostic.config().update_in_insert
  vim.diagnostic.config({ update_in_insert = enabled })
  vim.notify('Live diagnostics while typing: ' .. (enabled and 'on' or 'off'),
    vim.log.levels.INFO, { title = 'nvim-forge' })
end, { desc = 'Toggle live diagnostics while typing' })

-- Diagnostics UI -------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = {
    spacing = 2,
    prefix = '●',
    source = 'if_many',
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = 'E',
      [vim.diagnostic.severity.WARN] = 'W',
      [vim.diagnostic.severity.INFO] = 'I',
      [vim.diagnostic.severity.HINT] = 'H',
    },
  },
  underline = true,
  float = {
    border = 'rounded',
    source = 'if_many',
    header = '',
    prefix = '',
  },
  severity_sort = true,
  update_in_insert = false,
})

-- Optional "fix available" notifications while editing ----------------------
-- Toggle per clangd buffer with <leader>fn.  This uses a low-level codeAction
-- request so it can count fixes without opening the selection picker.
local function notify_quick_fixes(buf, client)
  if vim.b[buf].nvf_notify_fixes ~= true then
    return
  end
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= buf then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(win)[1] - 1
  local key = buf .. ':' .. lnum .. ':' .. (vim.b[buf].nvf_diag_tick or 0)
  if vim.b[buf].nvf_last_fix_check == key then
    return
  end
  vim.b[buf].nvf_last_fix_check = key

  local ns_push = vim.lsp.diagnostic.get_namespace(client.id)
  local lsp_diags = {}
  for _, d in ipairs(vim.diagnostic.get(buf, { namespace = ns_push, lnum = lnum })) do
    if d.user_data and d.user_data.lsp then
      table.insert(lsp_diags, d.user_data.lsp)
    end
  end
  local params = vim.lsp.util.make_range_params(win, client.offset_encoding)
  params.context = {
    diagnostics = lsp_diags,
    only = { 'quickfix' },
    triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Automatic,
  }
  client:request('textDocument/codeAction', params, function(err, result)
    if err or not result or vim.api.nvim_get_current_buf() ~= buf then
      return
    end
    local count = 0
    for _, a in ipairs(result) do
      if (a.kind == 'quickfix' or (a.kind and vim.startswith(a.kind, 'quickfix.')))
          and not a.disabled then
        count = count + 1
      end
    end
    if count > 0 then
      vim.notify(('%d clangd fix%s available here — <leader>ca to choose, '
        .. '<leader>cf to apply the first'):format(count, count == 1 and '' or 'es'),
        vim.log.levels.INFO, { title = 'nvim-forge' })
    end
  end, buf)
end

-- Hover / signature help floats -------------------------------------------
-- vim.lsp.handlers[...] and vim.lsp.with() are deprecated in Neovim 0.12;
-- borders are passed per call through vim.lsp.buf.hover()/signature_help().

-- Buffer-local mappings + per-buffer behaviour on attach ----------------------
local group = vim.api.nvim_create_augroup('nvf_lsp', { clear = true })

vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(ev)
    local buf = ev.buf
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
    end

    -- Navigation ------------------------------------------------------------
    map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')
    map('n', 'gD', vim.lsp.buf.declaration, 'Go to declaration')
    map('n', 'gr', vim.lsp.buf.references, 'Find references')
    map('n', 'gi', vim.lsp.buf.implementation, 'Go to implementation')
    -- `gt` / `gT` belong to tab navigation (next / previous tab); keep them
    -- free even in LSP-attached buffers.
    map('n', '<leader>gt', vim.lsp.buf.type_definition, 'Go to type definition')

    -- Documentation / actions ----------------------------------------------
    map('n', 'K', function()
      vim.lsp.buf.hover({ border = 'rounded', title = 'hover' })
    end, 'Hover documentation')
    map('n', '<C-k>', function()
      vim.lsp.buf.signature_help({ border = 'rounded', title = 'signature' })
    end, 'Signature help')
    map('n', '<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
    map({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, 'Code actions')
    map({ 'n', 'v' }, '<leader>cf', function()
      -- With one fix this applies it directly; with several it opens the chooser.
      vim.lsp.buf.code_action({ context = { only = { 'quickfix' } }, apply = true })
    end, 'Apply first quick fix (or choose)')
    map({ 'n', 'v' }, '<leader>lf', function()
      vim.lsp.buf.code_action({ context = { only = { 'quickfix' } } })
    end, 'List quick fixes')

    -- Diagnostics -----------------------------------------------------------
    map('n', '[d', function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, 'Previous diagnostic')
    map('n', ']d', function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, 'Next diagnostic')
    -- NB: <leader>e is the explorer toggle (forge.explorer); the global
    -- <leader>d mapping already opens the diagnostic float in LSP buffers.
    map('n', '<leader>ql', vim.diagnostic.setloclist, 'Diagnostics to loclist')

    -- Reference highlight (cleared on CursorMoved) ---------------------------
    local hl = vim.api.nvim_create_augroup('nvf_lsp_refs_' .. buf, { clear = true })
    if client and client:supports_method('textDocument/documentHighlight') then
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        group = hl, buffer = buf,
        callback = function() vim.lsp.buf.document_highlight() end,
      })
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = hl, buffer = buf,
        callback = function() vim.lsp.buf.clear_references() end,
      })
      vim.api.nvim_create_autocmd('LspDetach', {
        group = hl, buffer = buf,
        callback = function()
          pcall(vim.lsp.buf.clear_references)
          pcall(vim.api.nvim_del_augroup_by_id, hl)
        end,
      })
    end

    -- Rust: unobtrusive type inlay hints ------------------------------------
    if client and client.name == 'rust_analyzer' then
      pcall(vim.lsp.inlay_hint.enable, true, { bufnr = buf })
      map('n', '<leader>ih', function()
        local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
      end, 'Toggle inlay hints')
    end

    -- C/C++: opt-in notifications when clangd has quick fixes at the cursor --
    if client and client.name == 'clangd' then
      local fix_group = vim.api.nvim_create_augroup('nvf_lsp_fixes_' .. buf, { clear = true })
      vim.api.nvim_create_autocmd('CursorHold', {
        group = fix_group, buffer = buf,
        callback = function() notify_quick_fixes(buf, client) end,
      })
      vim.api.nvim_create_autocmd('DiagnosticChanged', {
        group = fix_group, buffer = buf,
        callback = function()
          vim.b[buf].nvf_diag_tick = (vim.b[buf].nvf_diag_tick or 0) + 1
        end,
      })
      vim.api.nvim_create_autocmd('LspDetach', {
        group = fix_group, buffer = buf,
        callback = function()
          pcall(vim.api.nvim_del_augroup_by_id, fix_group)
        end,
      })
      map('n', '<leader>fn', function()
        vim.b[buf].nvf_notify_fixes = not vim.b[buf].nvf_notify_fixes
        vim.notify('clangd fix notifications: '
          .. (vim.b[buf].nvf_notify_fixes and 'on (rest the cursor on a diagnostic)'
            or 'off'), vim.log.levels.INFO, { title = 'nvim-forge' })
      end, 'Toggle clangd fix notifications')
    end
  end,
})
