return {
  'catppuccin/nvim',
  name = 'catppuccin-colorscheme',
  priority = 1000,
  lazy = false,
  init = function()
    vim.cmd.colorscheme('catppuccin')
  end,
  config = function()
    require('catppuccin').setup {
      custom_highlights = function()
        return {
          BlinkCmpLabelMatch = { italic = true, bold = true, fg = 'NONE' }
        }
      end,
      integrations = {
        blink_cmp = true
      }
    }
  end
}
