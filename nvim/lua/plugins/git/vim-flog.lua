return {
  'rbong/vim-flog',
  init = function()
    vim.g.flog_enable_extended_chars = true
  end,
  cmd = { 'Flog', 'Flogsplit', 'Floggit' },
  keys = {
    { '<S-M-l>', function() vim.cmd('vertical Flogsplit') end, desc = 'Display git graph' },
    { '<S-D-l>', function() vim.cmd('vertical Flogsplit') end, desc = 'Display git graph' }
  },
  dependencies = {
    'tpope/vim-fugitive',
  },
}
