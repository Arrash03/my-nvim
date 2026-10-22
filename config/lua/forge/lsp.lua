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
vim.lsp.config('clangd', {
  cmd = {
    forge_home .. '/servers/clangd/bin/clangd',
    '--background-index',
    '--clang-tidy',
    '--header-insertion=never',
    '--completion-style=detailed',
    '--fallback-style=LLVM',
    '-j=4',
  },
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
    map('n', 'gt', vim.lsp.buf.type_definition, 'Go to type definition')

    -- Documentation / actions ----------------------------------------------
    map('n', 'K', function()
      vim.lsp.buf.hover({ border = 'rounded', title = 'hover' })
    end, 'Hover documentation')
    map('n', '<C-k>', function()
      vim.lsp.buf.signature_help({ border = 'rounded', title = 'signature' })
    end, 'Signature help')
    map('n', '<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
    map({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, 'Code actions')

    -- Diagnostics -----------------------------------------------------------
    map('n', '[d', function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, 'Previous diagnostic')
    map('n', ']d', function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, 'Next diagnostic')
    map('n', '<leader>e', vim.diagnostic.open_float, 'Show diagnostic details')
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
  end,
})
