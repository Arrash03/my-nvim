--[[
  Completion: nvim-cmp with LSP + snippet + current-buffer sources.

  Tab/Shift-Tab contract:
    * menu visible  -> next / previous item
    * snippet active -> expand / jump forward / backward
    * otherwise     -> falls through to the default behaviour, so plain
                       Tab-indentation stays reliable.
  CR accepts the first suggestion when the menu is open (even with
  completeopt=noselect), otherwise it inserts a newline.  <C-Space> explicitly
  opens the menu, <C-e> aborts, <C-d>/<C-f> scroll the documentation.
]]

local cmp = require('cmp')
local luasnip = require('luasnip')

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  window = {
    completion = cmp.config.window.bordered({
      border = 'rounded',
      winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None',
    }),
    documentation = cmp.config.window.bordered({
      border = 'rounded',
      winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,Search:None',
    }),
  },
  -- Make every suggestion self-describing: kind + originating source.
  formatting = {
    fields = { 'abbr', 'kind', 'menu' },
    format = function(entry, item)
      local kinds = {
        Text = 'txt', Method = 'fn', Function = 'fn', Constructor = 'fn',
        Field = 'fld', Variable = 'var', Class = 'cls', Interface = 'ifc',
        Module = 'mod', Property = 'prop', Enum = 'enum', Keyword = 'kw',
        Snippet = 'snip', File = 'file', Reference = 'ref', Constant = 'const',
      }
      item.kind = kinds[item.kind] or item.kind or ''
      item.menu = ({
        nvim_lsp = 'LSP',
        luasnip = 'Snip',
        buffer = 'Buf',
      })[entry.source.name] or entry.source.name
      return item
    end,
  },
  completion = { autocompletion = true },
  mapping = cmp.mapping.preset.insert({
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
      elseif luasnip.expand_or_locally_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
      elseif luasnip.locally_jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<CR>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        -- `noselect` keeps the cursor put, but Enter should still be a useful
        -- "accept the suggestion" key.  select=true makes the first item the
        -- target when nothing has been explicitly selected yet.
        cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
  }),
  -- LSP first; buffer words only as a secondary, length-filtered source.
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  }, {
    { name = 'buffer', keyword_length = 2 },
  }),
  performance = {
    fetching_timeout = 500,
  },
})

-- Slash-search: buffer words only (unobtrusive).
cmp.setup.cmdline({ '/', '?' }, {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'buffer' },
  },
})

-- nvim-autopairs: confirm LSP-driven expansions together with completion.
-- Note: the `.completion.cmp` module only exposes the confirm_done handler;
-- setup() lives on the main nvim-autopairs module.
local ok_ap, autopairs = pcall(require, 'nvim-autopairs')
if ok_ap then
  pcall(function() autopairs.setup({}) end)
end
local ok, cmp_autopairs = pcall(require, 'nvim-autopairs.completion.cmp')
if ok then
  cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
end
