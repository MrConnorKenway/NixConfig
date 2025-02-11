---@type LazyPluginSpec
return {
  'folke/flash.nvim',
  event = 'VeryLazy',
  opts = { labels = 'asdfjkl;weionmcvgh' },
  keys = {
    {
      'S',
      function()
        require('flash').treesitter({ label = { rainbow = { enabled = true } } })
      end,
      desc = 'Flash Treesitter'
    },
    { 's', function() require('flash').jump() end, desc = 'Flash' },
  }
}
