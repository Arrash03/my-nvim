--[[
  Statusline: lualine with a custom "nvf" theme matched to the forge
  colorscheme.  No dev-icons dependency: the line is built from text and
  color only, which works in any terminal.
]]

local c = {
  bg0 = '#0D0F12', bg1 = '#13161C', bg3 = '#202734',
  fg0 = '#D5DAE5', fg2 = '#7E8798', fg3 = '#5A6373',
  blue = '#7EA6E0', green = '#8FB56B', purple = '#A78BD9',
  red = '#E06070', yellow = '#D8C07A', aqua = '#6FB3AE', orange = '#D99A5B',
}

local nvf_theme = {
  normal = {
    a = { bg = c.blue,   fg = c.bg0, gui = 'bold' },
    b = { bg = c.bg1,    fg = c.fg0 },
    c = { bg = c.bg0,    fg = c.fg2 },
  },
  insert = { a = { bg = c.green,  fg = c.bg0, gui = 'bold' }, b = { bg = c.bg1, fg = c.fg0 }, c = { bg = c.bg0, fg = c.fg2 } },
  visual = { a = { bg = c.purple, fg = c.bg0, gui = 'bold' }, b = { bg = c.bg1, fg = c.fg0 }, c = { bg = c.bg0, fg = c.fg2 } },
  replace = { a = { bg = c.red,    fg = c.bg0, gui = 'bold' }, b = { bg = c.bg1, fg = c.fg0 }, c = { bg = c.bg0, fg = c.fg2 } },
  command = { a = { bg = c.yellow, fg = c.bg0, gui = 'bold' }, b = { bg = c.bg1, fg = c.fg0 }, c = { bg = c.bg0, fg = c.fg2 } },
  terminal = { a = { bg = c.aqua,  fg = c.bg0, gui = 'bold' }, b = { bg = c.bg1, fg = c.fg0 }, c = { bg = c.bg0, fg = c.fg2 } },
  inactive = {
    a = { bg = c.bg1, fg = c.fg3 },
    b = { bg = c.bg0, fg = c.fg3 },
    c = { bg = c.bg0, fg = c.fg3 },
  },
}

-- LSP client names attached to the current buffer ("" when none).
local function lsp_status()
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    names[#names + 1] = client.name
  end
  if #names == 0 then
    return ''
  end
  return 'LSP: ' .. table.concat(names, ', ')
end

-- Git branch, but only if git exists on the machine (it is not bundled).
local function git_branch()
  if vim.fn.executable('git') ~= 1 then
    return ''
  end
  local dir = vim.fn.expand('%:p:h')
  if dir == '' then
    return ''
  end
  local branch = vim.fn.system({
    'git', '-C', dir, 'rev-parse', '--abbrev-ref', 'HEAD',
  })
  if vim.v.shell_error ~= 0 then
    return ''
  end
  return branch:gsub('%s+$', '')
end

require('lualine').setup({
  options = {
    theme = nvf_theme,
    icons_enabled = false,
    section_separators = { left = '', right = '' },
    component_separators = { left = '│', right = '│' },
    globalstatus = true,
    disabled_filetypes = { statusline = { 'NvimTree' } },
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { git_branch, 'diagnostics' },
    lualine_c = {
      { 'filename', path = 1, symbols = { modified = ' [+]', readonly = ' [RO]' } },
    },
    lualine_x = { lsp_status, 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { 'filename' },
    lualine_x = { 'location' },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {},
  extensions = {},
})
