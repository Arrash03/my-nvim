--[[
  File navigation: telescope.nvim (+ plenary).

  `find` ships with every normal Linux userland, so find_files works on a
  bare system.  live_grep prefers ripgrep when present; on systems without
  rg we fall back to grep(1) and populate the quickfix list, so the
  mapping never silently breaks.
]]

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
        ['<Esc>'] = require('telescope.actions').close,
        ['<C-j>'] = require('telescope.actions').move_selection_next,
        ['<C-k>'] = require('telescope.actions').move_selection_previous,
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
    vim.fn.setqflist({}, ' ', {
      title = 'grep: ' .. pattern,
      lines = vim.fn.systemlist({
        'grep', '-rn', '--binary-files=without-match',
        '--exclude-dir=.git', '--exclude-dir=node_modules',
        '--exclude-dir=target', '--', pattern, '.',
      }),
    })
    if vim.fn.getqflist({ size = 0 }).size == 0 then
      vim.notify('No matches for: ' .. pattern, vim.log.levels.INFO)
    else
      vim.cmd('copen')
    end
  end
end

map('n', '<leader>fg', grep_args(), { desc = 'Live grep (rg or grep fallback)' })
