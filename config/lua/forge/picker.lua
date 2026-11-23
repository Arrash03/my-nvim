--[[
  File navigation: telescope.nvim (+ plenary).

  `find` ships with every normal Linux userland, so find_files works on a
  bare system.  live_grep prefers ripgrep when present; on systems without
  rg we fall back to grep(1) and populate the quickfix list, so the
  mapping never silently breaks.  In both cases <C-t> opens the selected
  result in a new tab: Telescope uses its own action, quickfix/location
  lists use forge.picker.open_entry_in_tab().
]]

local actions = require('telescope.actions')

require('telescope').setup({
  defaults = {
    prompt_prefix = '  ',
    selection_caret = '» ',
    entry_prefix = '  ',
    sorting_strategy = 'ascending',
    layout_config = {
      prompt_position = 'top',
      width = 0.75,
      height = 0.80,
    },
    file_ignore_patterns = { '.git/', 'node_modules/', 'target/debug/' },
    mappings = {
      i = {
        ['<Esc>'] = actions.close,
        ['<C-j>'] = actions.move_selection_next,
        ['<C-k>'] = actions.move_selection_previous,
        -- Explicitly configured so search results can always be opened in a
        -- separate tab, even if Telescope defaults change later.
        ['<C-t>'] = actions.select_tab,
      },
      n = {
        ['<C-t>'] = actions.select_tab,
      },
    },
  },
  pickers = {
    find_files = {
      hidden = false,          -- respect .gitignore semantics by default
      no_ignore = false,
    },
    buffers = {
      sort_mru = true,
      ignore_current_buffer = true,
    },
  },
})

local map = vim.keymap.set
local builtin = require('telescope.builtin')

map('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
map('n', '<leader>fb', builtin.buffers, { desc = 'Buffers' })
map('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
map('n', '<leader>fo', builtin.oldfiles, { desc = 'Recent files' })
map('n', '<leader>fd', builtin.diagnostics, { desc = 'Diagnostics' })
map('n', '<leader>fs', builtin.lsp_document_symbols, { desc = 'Document symbols' })
map('n', '<leader>fr', builtin.resume, { desc = 'Resume picker' })

-- Grep: ripgrep when available, grep(1)+quickfix fallback otherwise. --------
local M = {}

local function split_globs(value)
  local globs = {}
  for _, item in ipairs(vim.split(value or '', ',',
      { plain = true, trimempty = true })) do
    item = vim.trim(item)
    if item ~= '' then globs[#globs + 1] = item end
  end
  return globs
end

local function normalize_globs(value)
  if type(value) == 'string' then return split_globs(value) end
  return value or {}
end

function M.build_grep_command(pattern, include, exclude)
  local cmd = {
    'grep', '-rn', '--binary-files=without-match',
    '--exclude-dir=.git', '--exclude-dir=node_modules',
    '--exclude-dir=target',
  }
  for _, glob in ipairs(normalize_globs(include)) do
    cmd[#cmd + 1] = '--include=' .. glob
  end
  for _, glob in ipairs(normalize_globs(exclude)) do
    if glob:sub(-1) == '/' then
      cmd[#cmd + 1] = '--exclude-dir=' .. glob:sub(1, -2)
    else
      cmd[#cmd + 1] = '--exclude=' .. glob
    end
  end
  vim.list_extend(cmd, { '--', pattern, '.' })
  return cmd
end

local function run_grep(pattern, include, exclude)
  local lines = vim.fn.systemlist(
    M.build_grep_command(pattern, include, exclude))
  vim.fn.setqflist({}, ' ', { title = 'grep: ' .. pattern, lines = lines })
  if vim.fn.getqflist({ size = 0 }).size == 0 then
    vim.notify('No matches for: ' .. pattern, vim.log.levels.INFO)
  else
    vim.cmd('copen')
  end
end

local function grep_args()
  if vim.fn.executable('rg') == 1 then
    return builtin.live_grep
  end
  -- Fallback: grep -rn over the cwd, results to the quickfix list.
  return function()
    local pattern = vim.fn.input('Grep pattern: ')
    if pattern == '' then
      return
    end
    run_grep(pattern)
  end
end

--- Search with optional include/exclude file globs.
---
--- With ripgrep installed this opens Telescope live_grep with rg --glob
--- arguments.  On the offline target (no rg) it runs grep(1) and fills the
--- quickfix list, using --include/--exclude (and --exclude-dir for a glob
--- ending in "/").
---@param opts? { pattern?: string, include?: string|string[], exclude?: string|string[], force_grep?: boolean }
function M.grep_with_filters(opts)
  opts = opts or {}
  local pattern = opts.pattern
  if pattern == nil or pattern == '' then
    pattern = vim.fn.input('Grep pattern: ')
    if pattern == '' then return end
  end
  local include = opts.include
  if include == nil then
    include = vim.fn.input(
      'Include globs (comma-separated; blank = all files): ')
  end
  local exclude = opts.exclude
  if exclude == nil then
    exclude = vim.fn.input(
      'Exclude globs (comma-separated; blank = none): ')
  end
  include = normalize_globs(include)
  exclude = normalize_globs(exclude)

  if vim.fn.executable('rg') == 1 and not opts.force_grep then
    local globs = {}
    for _, glob in ipairs(include) do globs[#globs + 1] = glob end
    for _, glob in ipairs(exclude) do
      globs[#globs + 1] = glob:sub(-1) == '/' and '!' .. glob .. '**'
        or '!' .. glob
    end
    builtin.live_grep({ default_text = pattern, glob_pattern = globs })
  else
    run_grep(pattern, include, exclude)
  end
end

map('n', '<leader>fg', grep_args(), { desc = 'Live grep (rg or grep fallback)' })
map('n', '<leader>fG', function() M.grep_with_filters() end,
  { desc = 'Grep with include/exclude filters' })

-- Quickfix / location-list results (the no-rg grep fallback, git changes,
-- diagnostics, LSP references) get the same "open in another tab" key as
-- Telescope.  The list stays visible in the original tab.
local function entry_at_cursor()
  local index = vim.fn.line('.')
  -- In a location-list window getloclist(0) is populated; in a quickfix
  -- window it is empty and the global quickfix list is the right source.
  local loc_size = vim.fn.getloclist(0, { size = 0 }).size or 0
  local entries = loc_size > 0 and vim.fn.getloclist(0) or vim.fn.getqflist()
  return entries[index]
end

function M.open_entry_in_tab()
  local entry = entry_at_cursor()
  if not entry then
    vim.notify('No search result under cursor', vim.log.levels.INFO)
    return
  end

  local filename = entry.filename or ''
  local has_buffer = entry.bufnr and entry.bufnr ~= 0
    and vim.api.nvim_buf_is_valid(entry.bufnr)
    and vim.api.nvim_buf_get_name(entry.bufnr) ~= ''
  if not has_buffer and filename == '' then
    vim.notify('Search result has no file to open', vim.log.levels.INFO)
    return
  end

  vim.cmd('tabnew')
  if has_buffer then
    vim.cmd('buffer ' .. entry.bufnr)
  else
    vim.cmd('edit ' .. vim.fn.fnameescape(filename))
  end
  pcall(vim.api.nvim_win_set_cursor, 0, {
    math.max(1, entry.lnum or 1),
    math.max(0, (entry.col or 1) - 1),
  })
  vim.cmd('normal! zz')
end

local augroup = vim.api.nvim_create_augroup('nvf_picker_qf', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = augroup,
  pattern = 'qf',
  callback = function(args)
    vim.keymap.set('n', '<C-t>', M.open_entry_in_tab, {
      buffer = args.buf,
      silent = true,
      desc = 'Open search result in another tab',
    })
  end,
})

return M
