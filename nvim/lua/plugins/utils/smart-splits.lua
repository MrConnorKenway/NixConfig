---@type LazyPluginSpec
return {
  'mrjones2014/smart-splits.nvim',
  keys = {
    {
      '<C-h>',
      mode = { 'n', 'i', 't' },
      function()
        require('smart-splits').move_cursor_left()
      end,
      desc = 'Move cursort left',
    },
    {
      '<C-j>',
      mode = { 'n', 'i', 't' },
      function()
        require('smart-splits').move_cursor_down()
      end,
      desc = 'Move cursort down',
    },
    {
      '<C-k>',
      mode = { 'n', 'i', 't' },
      function()
        require('smart-splits').move_cursor_up()
      end,
      desc = 'Move cursort up',
    },
    {
      '<C-l>',
      mode = { 'n', 'i' },
      function()
        require('smart-splits').move_cursor_right()
      end,
      desc = 'Move cursort right',
    },
    {
      '<M-h>',
      mode = { 'n', 'i', 't' },
      function()
        require('smart-splits').resize_left()
      end,
      desc = 'Resize window left',
    },
    {
      '<M-j>',
      mode = { 'n', 'i', 't' },
      function()
        require('smart-splits').resize_down()
      end,
      desc = 'Resize window down',
    },
    {
      '<M-k>',
      mode = { 'n', 'i', 't' },
      function()
        require('smart-splits').resize_up()
      end,
      desc = 'Resize window up',
    },
    {
      '<M-l>',
      mode = { 'n', 'i', 't' },
      function()
        require('smart-splits').resize_right()
      end,
      desc = 'Resize window right',
    },
  },
  opts = {
    default_amount = 3,
  },
}
