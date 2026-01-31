---@type LazyPluginSpec
return {
  'TheNoeTrevino/haunt.nvim',
  lazy = false,
  keys = {
    {
      '<leader>m',
      function()
        require('haunt.picker').show()
      end,
      desc = 'Show all bookmarks',
    },
    {
      '<D-k>',
      function()
        require('haunt.api').annotate()
      end,
      desc = 'Create a new bookmark',
    },
  },
  opts = {},
}
