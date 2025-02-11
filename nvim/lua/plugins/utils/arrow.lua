---@type LazyPluginSpec
return {
  'otavioschwanck/arrow.nvim',
  event = 'UIEnter',
  keys = {
    { '<C-S-n>', function() require('arrow.persist').next() end,     desc = 'Move to next arrow buffer' },
    { '<C-S-p>', function() require('arrow.persist').previous() end, desc = 'Move to previous arrow buffer' }
  },
  dependencies = {
    { 'nvim-tree/nvim-web-devicons' },
  },
  opts = {
    show_icons = true,
    leader_key = 'm',
    window = {
      border = 'rounded'
    }
  }
}
