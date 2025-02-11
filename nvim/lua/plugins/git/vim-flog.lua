---@type LazyPluginSpec
return {
  'rbong/vim-flog',
  init = function()
    vim.g.flog_enable_extended_chars = true
  end,
  keys = {
    { '<S-M-l>', mode = 'n', '<cmd>Flog<cr>',  desc = 'Display git graph' },
    { '<S-M-l>', mode = 'v', ":'<,'>Flog<cr>", desc = 'Display git log of visual selected range', silent = true },
    { '<S-D-l>', mode = 'n', '<cmd>Flog<cr>',  desc = 'Display git graph' },
    { '<S-D-l>', mode = 'v', ":'<,'>Flog<cr>", desc = 'Display git log of visual selected range', silent = true }
  },
  dependencies = {
    'tpope/vim-fugitive',
  },
}
