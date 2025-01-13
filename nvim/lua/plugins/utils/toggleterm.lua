return {
  'akinsho/toggleterm.nvim',
  keys = {
    {
      '<D-j>',
      mode = { 'n', 'i', 't' },
      function() require('toggleterm').toggle(nil, nil, nil, 'float', nil) end,
      desc = 'Toggle terminal at current window'
    },
    {
      '<C-`>',
      mode = { 'n', 'i', 't' },
      function() require('toggleterm').toggle(nil, nil, nil, 'float', nil) end,
      desc = 'Toggle terminal at current window'
    },
  },
  opts = {
    size = 16,
    shade_terminals = true,
    float_opts = { border = 'rounded' }
  }
}
