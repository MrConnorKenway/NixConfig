---@module 'blink.cmp'

---@type LazyPluginSpec
return {
  'saghen/blink.cmp',
  lazy = false, -- lazy loading handled internally
  version = '*',
  ---@type blink.cmp.Config
  opts = {
    keymap = {
      ['<C-space>'] = {
        'show',
        'show_documentation',
        'hide_documentation',
        'fallback',
      },
      ['<C-;>'] = { 'hide', 'fallback' },
      ['<CR>'] = { 'select_and_accept', 'fallback' },
      ['<Tab>'] = { 'select_and_accept', 'snippet_forward', 'fallback' },
      ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
      ['<C-p>'] = { 'select_prev', 'fallback' },
      ['<C-n>'] = { 'select_next', 'fallback' },
      ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
      ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
    },
    cmdline = {
      keymap = {
        ['<C-space>'] = {
          'show',
          'fallback',
        },
        ['<C-e>'] = { 'fallback' },
        ['<C-;>'] = { 'hide', 'fallback' },
        ['<Tab>'] = { 'select_and_accept', 'fallback' },
        ['<C-p>'] = { 'select_prev', 'fallback' },
        ['<C-n>'] = { 'select_next', 'fallback' },
      },
      completion = {
        menu = { auto_show = true },
        ghost_text = { enabled = false },
      },
    },
    sources = {
      default = { 'lsp', 'path' },
      providers = { cmdline = { min_keyword_length = 0 } },
    },
    completion = {
      accept = { auto_brackets = { enabled = false } },
      list = { selection = { auto_insert = false } },
      menu = {
        winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None',
        draw = { treesitter = { 'lsp' } },
        border = 'rounded',
      },
      documentation = {
        auto_show = true,
        window = {
          winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpDocCursorLine,Search:None',
          border = 'rounded',
        },
      },
    },
    signature = {
      enabled = true,
      window = {
        winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpDocCursorLine,Search:None',
        border = 'rounded',
      },
    },
  },
}
