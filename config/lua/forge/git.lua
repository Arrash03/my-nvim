--[[
  Lightweight Git Lens / blame support.
  ---------------------------------------------------------------------------
  Git is deliberately NOT bundled: the editor stays fully offline and works
  without it.  When a `git` executable is on PATH, this module adds:

    * signcolumn marks for added / modified / deleted lines in the current
      buffer (both staged and unstaged), refreshed on entry and after :w
    * inline blame virtual text (`:NVFGitBlame`), parsed from `git blame`
    * a quickfix list of every changed/untracked file (`:NVFGitChanges`)
    * [g / ]g to jump between changed lines in the current buffer

  All git work is asynchronous via vim.system(); nothing is downloaded.
]]

local M = {}

local ns = vim.api.nvim_create_namespace('forge_git')
local changed = {}   -- bufnr -> { [lnum] = 'add'|'delete' }
local gens = {}      -- bufnr -> refresh generation (discard stale callbacks)

local function available()
  return vim.fn.executable('git') == 1
end

local function run(args, cwd, cb)
  if vim.fn.isdirectory(cwd) ~= 1 then
    cb(nil)
    return
  end
  local cmd = vim.list_extend({ 'git' }, args)
  vim.system(cmd, { cwd = cwd, text = true }, function(res)
    vim.schedule(function()
      cb(res.code == 0 and (res.stdout or '') or nil)
    end)
  end)
end

local signs = {
  add    = { text = '+', hl = 'ForgeGitAdd' },
  delete = { text = '-', hl = 'ForgeGitDelete' },
}

-- `git diff --unified=0` hunk parser ---------------------------------------
local function parse_diff(text)
  local marks = {}
  local in_hunk, new_lnum = false, 0
  for line in (text or ''):gmatch('([^\n]*)\n') do
    local start = line:match('^@@ .* %+(%d+)')
    if start then
      in_hunk = true
      new_lnum = tonumber(start)
    elseif in_hunk then
      local c = line:sub(1, 1)
      if c == '+' then
        marks[new_lnum] = 'add'
        new_lnum = new_lnum + 1
      elseif c == '-' then
        local d = math.max(1, new_lnum - 1)
        if marks[d] ~= 'add' then marks[d] = 'delete' end
      elseif c == ' ' then
        new_lnum = new_lnum + 1
      elseif c ~= '\\' then
        in_hunk = false
      end
    end
  end
  return marks
end

local function merge_marks(dst, src)
  for lnum, kind in pairs(src or {}) do
    if kind == 'add' or dst[lnum] == nil then dst[lnum] = kind end
  end
end

-- `git blame --line-porcelain` parser --------------------------------------
local function parse_blame(text)
  local blame, cur = {}, nil
  for line in (text or ''):gmatch('([^\n]*)\n') do
    local sha, _, final = line:match('^(%x+) (%d+) (%d+)')
    if sha then
      cur = { lnum = tonumber(final) }
    elseif cur and line:sub(1, 7) == 'author ' then
      cur.author = line:sub(8)
    elseif cur and line:sub(1, 12) == 'author-time ' then
      cur.time = tonumber(line:sub(13))
    elseif cur and line:sub(1, 8) == 'summary ' then
      cur.summary = line:sub(9)
    elseif cur and line:sub(1, 1) == '\t' then
      blame[cur.lnum] = cur
      cur = nil
    end
  end
  return blame
end

local function truncate(s, n)
  s = s or ''
  return #s > n and (s:sub(1, n - 1) .. '…') or s
end

local function relative_date(ts)
  local diff = os.time() - (ts or 0)
  if diff < 0 then return 'now' end
  if diff < 60 then return 'now' end
  if diff < 3600 then return math.floor(diff / 60) .. 'm ago' end
  if diff < 86400 then return math.floor(diff / 3600) .. 'h ago' end
  if diff < 2592000 then return math.floor(diff / 86400) .. 'd ago' end
  if diff < 31536000 then return math.floor(diff / 2592000) .. 'mo ago' end
  return math.floor(diff / 31536000) .. 'y ago'
end

local function blame_label(info)
  return truncate(info.author or '?', 14) .. ' · '
    .. relative_date(info.time) .. ' · '
    .. truncate(info.summary or '', 28)
end

-- Refresh signs (and blame, if enabled) for one buffer ---------------------
function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local gen = (gens[buf] or 0) + 1
  gens[buf] = gen
  pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
  changed[buf] = {}

  if not available() or vim.bo[buf].buftype ~= '' then return end
  local path = vim.api.nvim_buf_get_name(buf)
  if path == '' then return end
  local rel = vim.fn.fnamemodify(path, ':t')
  local cwd = vim.fn.fnamemodify(path, ':h')

  local acc, pending = {}, 2
  local function collect(text)
    merge_marks(acc, parse_diff(text))
    pending = pending - 1
    if pending ~= 0 or gens[buf] ~= gen or not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    changed[buf] = acc
    for lnum, kind in pairs(acc) do
      local s = signs[kind] or signs.delete
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, 0, {
        sign_text = s.text,
        sign_hl_group = s.hl,
        priority = 10,
      })
    end
  end

  run({ 'diff', '--no-ext-diff', '--unified=0', '--', rel }, cwd, collect)
  run({ 'diff', '--cached', '--no-ext-diff', '--unified=0', '--', rel }, cwd, collect)

  if vim.b[buf].nvf_git_blame then
    run({ 'blame', '--line-porcelain', '--', rel }, cwd, function(text)
      if gens[buf] ~= gen or not vim.api.nvim_buf_is_valid(buf) or not text then return end
      for lnum, info in pairs(parse_blame(text)) do
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, 0, {
          virt_text = { { '  ' .. blame_label(info), 'ForgeGitBlame' } },
          virt_text_pos = 'eol',
          priority = 5,
        })
      end
    end)
  end
end

-- Toggle inline blame for the current buffer -------------------------------
function M.toggle_blame(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not available() then
    vim.notify('Git Lens: git executable not found (feature disabled)',
      vim.log.levels.WARN)
    return
  end
  vim.b[buf].nvf_git_blame = not vim.b[buf].nvf_git_blame
  M.refresh(buf)
  vim.notify('Git blame ' .. (vim.b[buf].nvf_git_blame and 'on' or 'off'),
    vim.log.levels.INFO)
end

-- List every changed / untracked file in the quickfix list -----------------
function M.changes()
  if not available() then
    vim.notify('Git Lens: git executable not found (feature disabled)',
      vim.log.levels.WARN)
    return
  end
  local cwd = vim.fn.getcwd()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= '' then cwd = vim.fn.fnamemodify(bufname, ':h') end

  run({ 'rev-parse', '--show-toplevel' }, cwd, function(root_text)
    local root = root_text and vim.trim(root_text) or cwd
    run({ 'status', '--porcelain=v1', '--untracked-files=all' }, root, function(text)
      local entries = {}
      for line in (text or ''):gmatch('([^\n]*)\n') do
        local code, path = line:sub(1, 2), line:sub(4)
        if path:find(' -> ', 1, true) then path = path:match('.* -> (.*)$') or path end
        local kind = 'changed'
        if code == '??' then kind = 'untracked'
        elseif code:find('A', 1, true) then kind = 'added'
        elseif code:find('D', 1, true) then kind = 'deleted'
        elseif code:find('R', 1, true) then kind = 'renamed'
        elseif code:find('M', 1, true) then kind = 'modified' end
        if path ~= '' then
          table.insert(entries, {
            filename = root .. '/' .. path,
            lnum = 1,
            col = 1,
            text = code .. '  ' .. kind,
          })
        end
      end
      vim.fn.setqflist(entries, ' ')
      if #entries == 0 then
        vim.cmd('cclose')
        vim.notify('Git Lens: no uncommitted changes', vim.log.levels.INFO)
      else
        vim.cmd('copen')
        vim.notify(string.format('Git Lens: %d changed file(s)', #entries),
          vim.log.levels.INFO)
      end
    end)
  end)
end

-- Jump between changed lines in the current buffer -------------------------
function M.jump_changed(direction)
  local marks = changed[vim.api.nvim_get_current_buf()] or {}
  local lines = {}
  for lnum in pairs(marks) do table.insert(lines, lnum) end
  if #lines == 0 then return end
  table.sort(lines)
  local cur = vim.fn.line('.')
  local target
  if direction > 0 then
    for _, lnum in ipairs(lines) do
      if lnum > cur then target = lnum; break end
    end
    target = target or lines[1]
  else
    for i = #lines, 1, -1 do
      if lines[i] < cur then target = lines[i]; break end
    end
    target = target or lines[#lines]
  end
  if not target or target > vim.fn.line('$') then return end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

-- Test/debug view of the current overlay state -----------------------------
function M.state(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  local signs_n, blame_n = 0, 0
  local sample = ''
  for _, m in ipairs(marks) do
    local ok, details = pcall(vim.api.nvim_buf_get_extmark_by_id, buf, ns, m[1],
      { details = true })
    if ok and details[3] then
      if details[3].sign_text then signs_n = signs_n + 1 end
      if details[3].virt_text then
        blame_n = blame_n + 1
        if sample == '' then
          sample = details[3].virt_text[1] and details[3].virt_text[1][1] or ''
        end
      end
    end
  end
  return {
    git = available(),
    changed = changed[buf] or {},
    signs = signs_n,
    blame = blame_n,
    sample = sample,
  }
end

-- Commands ------------------------------------------------------------------
vim.api.nvim_create_user_command('NVFGitChanges', function() M.changes() end,
  { desc = 'Git Lens: list changed/untracked files in the quickfix list' })
vim.api.nvim_create_user_command('NVFGitBlame', function() M.toggle_blame(0) end,
  { desc = 'Git Lens: toggle inline blame for the current buffer' })
vim.api.nvim_create_user_command('NVFGitRefresh', function() M.refresh(0) end,
  { desc = 'Git Lens: refresh change marks and blame' })

-- Keep overlays current -----------------------------------------------------
local augroup = vim.api.nvim_create_augroup('ForgeGit', { clear = true })
vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost' }, {
  group = augroup,
  callback = function(ev) M.refresh(ev.buf) end,
})

return M
