return {
  'rachartier/tiny-inline-diagnostic.nvim',
  event = 'UIEnter',
  config = function()
    vim.diagnostic.config { virtual_text = false }
    require('tiny-inline-diagnostic').setup {
      signs = {
        left = ' ',
        right = ' ',
        arrow = ' ',
        up_arrow = ' ',
        vertical = ' │',
        vertical_end = ' └',
      },
    }
  end,
}
