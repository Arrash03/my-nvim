--[[
  Kanagawa-Forge: a customized dark colorscheme derived from Kanagawa
  (Dragon variant).  Palette values were re-tuned for long sessions:
    * near-black #0D0F12 background (opaque, never transparent),
    * moderately saturated syntax colors (no neon),
    * comments kept clearly readable (#7E8798, ~4.4:1 on bg),
    * bold/italics used almost nowhere.
  All Tree-sitter, LSP, diagnostic, Pmenu and float groups are defined
  explicitly so the look is consistent across every surface.
]]

vim.o.termguicolors = true
vim.o.background = 'dark'
vim.g.colors_name = 'forge'

-- Palette ------------------------------------------------------------------
local c = {
  -- backgrounds (dragon-inspired, re-tuned around #0D0F12)
  bg0  = '#0D0F12',  -- editor background
  bg1  = '#13161C',  -- subtle panels
  bg2  = '#181D26',  -- cursorline / floats
  bg3  = '#202734',  -- selection
  bg4  = '#2A3242',  -- visual selection / pmenu sel

  -- foregrounds
  fg0  = '#D5DAE5',  -- primary text
  fg1  = '#AFB7C6',  -- secondary text
  fg2  = '#7E8798',  -- comments (readable, not dim)
  fg3  = '#5A6373',  -- line numbers, subtle chrome
  fg4  = '#3C4454',  -- very subtle borders

  -- syntax
  red    = '#E06070',  -- errors, strings (rust lifetimes), constants
  orange = '#D99A5B',  -- numbers, operators
  yellow = '#D8C07A',  -- constants, warnings
  green  = '#8FB56B',  -- strings
  aqua   = '#6FB3AE',  -- types
  blue   = '#7EA6E0',  -- functions, identifiers
  purple = '#A78BD9',  -- keywords, statements
  pink   = '#D98BA0',  -- punctuation, special

  -- ui
  diff_add    = '#1E2E22',
  diff_change = '#1E2636',
  diff_delete = '#33202A',
  ref         = '#26303F', -- lsp reference highlight
  match       = '#3A4456', -- search highlight
  incmatch    = '#4A5670', -- incremental search

  -- diagnostics
  diag_error = '#E06070',
  diag_warn  = '#D9A94F',
  diag_info  = '#79A9E0',
  diag_hint  = '#7FB59A',
}

local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Core editor chrome -------------------------------------------------------
hi('Normal',       { fg = c.fg0, bg = c.bg0 })
hi('NormalFloat',  { fg = c.fg0, bg = c.bg1 })
hi('FloatBorder',  { fg = c.fg4, bg = c.bg1 })
hi('FloatTitle',   { fg = c.blue, bg = c.bg1 })
hi('SignColumn',   { bg = c.bg0 })
hi('StatusLine',   { fg = c.fg0, bg = c.bg1 })
hi('StatusLineNC', { fg = c.fg3, bg = c.bg0 })
hi('TabLine',      { fg = c.fg2, bg = c.bg1 })
hi('TabLineSel',   { fg = c.fg0, bg = c.bg3 })
hi('VertSplit',    { fg = c.bg3, bg = c.bg0 })
hi('WinSeparator', { fg = c.bg3, bg = c.bg0 })
hi('CursorLine',   { bg = c.bg2 })
hi('CursorColumn', { bg = c.bg2 })
hi('ColorColumn',  { bg = c.bg1 })
hi('CursorLineNr', { fg = c.fg0, bg = c.bg2 })
hi('LineNr',       { fg = c.fg3, bg = c.bg0 })
hi('Visual',       { bg = c.bg4 })
hi('VisualNOS',    { bg = c.bg4 })
hi('Search',       { fg = c.fg0, bg = c.match })
hi('IncSearch',    { fg = c.bg0, bg = c.orange })
hi('CurSearch',    { fg = c.bg0, bg = c.orange })
hi('Substitute',   { fg = c.bg0, bg = c.yellow })
hi('MatchParen',   { fg = c.yellow, bg = c.bg4 })
hi('Directory',    { fg = c.blue })
hi('Title',        { fg = c.blue })
hi('Question',     { fg = c.green })
hi('MoreMsg',      { fg = c.green })
hi('ModeMsg',      { fg = c.fg0 })
hi('NonText',      { fg = c.fg4 })
hi('SpecialKey',   { fg = c.fg4 })
hi('Whitespace',   { fg = c.bg3 })
hi('EndOfBuffer',  { fg = c.bg0 })
hi('QuickFixLine', { bg = c.bg3 })
hi('WildMenu',     { fg = c.fg0, bg = c.bg4 })

-- Diff / git ---------------------------------------------------------------
hi('DiffAdd',    { bg = c.diff_add })
hi('DiffChange', { bg = c.diff_change })
hi('DiffDelete', { bg = c.diff_delete })
hi('DiffText',   { bg = c.diff_change, fg = c.blue })

-- Folds --------------------------------------------------------------------
hi('Folded',     { fg = c.fg2, bg = c.bg1 })
hi('FoldColumn', { fg = c.fg3, bg = c.bg0 })

-- Messages / errors --------------------------------------------------------
hi('ErrorMsg', { fg = c.red })
hi('WarningMsg', { fg = c.yellow })

-- Completion menu (Pmenu is used by both wildmenu and nvim-cmp) -------------
hi('Pmenu',      { fg = c.fg0, bg = c.bg1 })
hi('PmenuSel',   { fg = c.fg0, bg = c.bg4 })
hi('PmenuSbar',  { bg = c.bg1 })
hi('PmenuThumb', { bg = c.bg4 })
hi('PmenuExtra', { fg = c.fg2 })

-- Diagnostics --------------------------------------------------------------
hi('DiagnosticError',            { fg = c.diag_error })
hi('DiagnosticWarn',             { fg = c.diag_warn })
hi('DiagnosticInfo',             { fg = c.diag_info })
hi('DiagnosticHint',             { fg = c.diag_hint })
hi('DiagnosticOk',               { fg = c.green })
hi('DiagnosticUnderlineError',   { sp = c.diag_error, undercurl = true })
hi('DiagnosticUnderlineWarn',    { sp = c.diag_warn, undercurl = true })
hi('DiagnosticUnderlineInfo',    { sp = c.diag_info, undercurl = true })
hi('DiagnosticUnderlineHint',    { sp = c.diag_hint, undercurl = true })
hi('DiagnosticVirtualTextError', { fg = c.diag_error })
hi('DiagnosticVirtualTextWarn',  { fg = c.diag_warn })
hi('DiagnosticVirtualTextInfo',  { fg = c.diag_info })
hi('DiagnosticVirtualTextHint',  { fg = c.diag_hint })
hi('DiagnosticSignError',        { fg = c.diag_error })
hi('DiagnosticSignWarn',         { fg = c.diag_warn })
hi('DiagnosticSignInfo',         { fg = c.diag_info })
hi('DiagnosticSignHint',         { fg = c.diag_hint })

-- LSP ----------------------------------------------------------------------
hi('LspReferenceText',  { bg = c.ref })
hi('LspReferenceRead',  { bg = c.ref })
hi('LspReferenceWrite', { bg = c.ref, underline = true })
hi('LspCodeLens',       { fg = c.fg3 })
hi('LspCodeLensSeparator', { fg = c.fg4 })
hi('LspInlayHint',      { fg = c.fg3, bg = c.bg1 })
hi('LspSignatureActiveParameter', { fg = c.orange, bold = true })
hi('LspInfoBorder',     { fg = c.fg4, bg = c.bg1 })

-- Links for semantic tokens (nvim already links most of these; being
-- explicit keeps the palette stable across nvim versions).
for _, grp in ipairs({
  '@lsp.type.class', '@lsp.type.enum', '@lsp.type.interface',
  '@lsp.type.struct', '@lsp.type.type', '@lsp.type.typeParameter',
}) do hi(grp, { link = 'Type' }) end
hi('@lsp.type.namespace', { fg = c.aqua })
hi('@lsp.type.parameter', { fg = c.fg0 })
hi('@lsp.type.property',  { fg = c.fg1 })
hi('@lsp.type.variable',  { fg = c.fg0 })
hi('@lsp.type.function',  { fg = c.blue })
hi('@lsp.type.method',    { fg = c.blue })
hi('@lsp.type.keyword',   { fg = c.purple })
hi('@lsp.type.string',    { fg = c.green })
hi('@lsp.type.number',    { fg = c.orange })
hi('@lsp.type.comment',   { fg = c.fg2 })
hi('@lsp.type.lifetime',  { fg = c.red })
hi('@lsp.mod.defaultLibrary', { sp = c.fg3, underdotted = true })
hi('@lsp.typemod.variable.defaultLibrary', { fg = c.aqua })
hi('@lsp.typemod.function.defaultLibrary', { fg = c.aqua })

-- Tree-sitter captures ------------------------------------------------------
hi('@variable',          { fg = c.fg0 })
hi('@variable.builtin',  { fg = c.pink })
hi('@variable.parameter', { fg = c.fg0 })
hi('@variable.member',   { fg = c.fg1 })
hi('@constant',          { fg = c.yellow })
hi('@constant.builtin',  { fg = c.yellow })
hi('@constant.macro',    { fg = c.orange })
hi('@module',            { fg = c.fg1 })
hi('@module.builtin',    { fg = c.pink })
hi('@label',             { fg = c.orange })
hi('@string',            { fg = c.green })
hi('@string.escape',     { fg = c.orange })
hi('@string.special',    { fg = c.orange })
hi('@character',         { fg = c.green })
hi('@number',            { fg = c.orange })
hi('@number.float',      { fg = c.orange })
hi('@boolean',           { fg = c.yellow })
hi('@comment',           { fg = c.fg2 })
hi('@comment.todo',      { fg = c.yellow })
hi('@comment.error',     { fg = c.red })
hi('@comment.warning',   { fg = c.diag_warn })
hi('@comment.note',      { fg = c.diag_info })
hi('@operator',          { fg = c.fg1 })
hi('@punctuation',       { fg = c.fg2 })
hi('@punctuation.bracket', { fg = c.fg3 })
hi('@punctuation.delimiter', { fg = c.fg2 })
hi('@punctuation.special', { fg = c.pink })
hi('@keyword',           { fg = c.purple })
hi('@keyword.function',  { fg = c.purple })
hi('@keyword.operator',  { fg = c.fg1 })
hi('@keyword.import',    { fg = c.purple })
hi('@keyword.storageclass', { fg = c.purple })
hi('@keyword.directive', { fg = c.purple })
hi('@keyword.exception', { fg = c.purple })
hi('@function',          { fg = c.blue })
hi('@function.builtin',  { fg = c.aqua })
hi('@function.call',     { fg = c.blue })
hi('@function.macro',    { fg = c.orange })
hi('@function.method',   { fg = c.blue })
hi('@function.method.call', { fg = c.blue })
hi('@constructor',       { fg = c.aqua })
hi('@type',              { fg = c.aqua })
hi('@type.builtin',      { fg = c.aqua })
hi('@type.definition',   { fg = c.aqua })
hi('@type.qualifier',    { fg = c.purple })
hi('@attribute',         { fg = c.purple })
hi('@property',          { fg = c.fg1 })
hi('@field',             { fg = c.fg1 })
hi('@tag',               { fg = c.purple })
hi('@tag.attribute',     { fg = c.orange })
hi('@tag.delimiter',     { fg = c.fg2 })
hi('@embedded',          { fg = c.fg0 })

-- Diffs from treesitter / gitsigns-style groups ---------------------------
hi('@diff.plus',  { fg = c.green })
hi('@diff.minus', { fg = c.red })
hi('@diff.delta', { fg = c.blue })

-- Spell --------------------------------------------------------------------
hi('SpellBad',   { sp = c.diag_error, undercurl = true })
hi('SpellCap',   { sp = c.diag_warn, undercurl = true })
hi('SpellLocal', { sp = c.diag_info, undercurl = true })
hi('SpellRare',  { sp = c.diag_hint, undercurl = true })

-- Health / misc Nvim UI ----------------------------------------------------
hi('healthError',   { fg = c.diag_error })
hi('healthSuccess', { fg = c.green })
hi('healthWarning', { fg = c.diag_warn })
hi('MsgArea',       { fg = c.fg0 })
hi('Question',      { fg = c.green })

-- Make sure comments and strings never get bold/italic by default links.
hi('Comment', { fg = c.fg2, italic = false })
