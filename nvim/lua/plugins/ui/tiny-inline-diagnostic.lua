return {
  'rachartier/tiny-inline-diagnostic.nvim',
  event = 'UIEnter',
  config = function()
    vim.diagnostic.config({ virtual_text = false })
    require('tiny-inline-diagnostic').setup {
      options = {
        use_icons_from_diagnostic = true
      },
      signs = {
        left = " ",
        right = " ",
        diag = "●",
        arrow = "    ",
        up_arrow = "    ",
        vertical = " │",
        vertical_end = " └",
      }
    }
  end
}
