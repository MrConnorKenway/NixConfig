---@type LazyPluginSpec
return {
  'fnune/recall.nvim',
  event = 'BufReadPost',
  keys = {
    {
      '<leader>m',
      function()
        require('recall.snacks').pick()
      end,
      desc = 'Show all bookmarks',
    },
    {
      '<D-k>',
      function()
        require('recall').toggle()
      end,
      desc = 'Toggle bookmark',
    },
  },
  opts = {},
}
