return {
  'rbong/vim-flog',
  init = function()
    vim.g.flog_enable_extended_chars = true
  end,
  keys = {
    { '<S-M-l>', '<cmd>Flog<cr>', desc = 'Display git graph' },
    { '<S-D-l>', '<cmd>Flog<cr>', desc = 'Display git graph' }
  },
  dependencies = {
    'tpope/vim-fugitive',
  },
}
