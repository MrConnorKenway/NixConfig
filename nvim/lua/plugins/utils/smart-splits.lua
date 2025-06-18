local function at_bottom_edge()
  return vim.fn.winnr() == vim.fn.winnr('j')
end

local move_cursor_down_key =
  vim.api.nvim_replace_termcodes('<C-j>', true, false, true)

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
        if at_bottom_edge() then
          vim.api.nvim_feedkeys(move_cursor_down_key, 'n', false)
        else
          require('smart-splits').move_cursor_down()
        end
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
