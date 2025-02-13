---@type LazyPluginSpec
return {
  'folke/todo-comments.nvim',
  event = 'UIEnter',
  dependencies = { 'nvim-lua/plenary.nvim' },
  opts = {
    signs = false,
  },
}
