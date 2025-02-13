---@type LazyPluginSpec
return {
  'landonb/vim-buffer-ring',
  event = 'VeryLazy',
  config = function()
    vim.keymap.set(
      'n',
      '[b',
      '<cmd>BufferRingReverse<cr>',
      { desc = 'Previous buffer' }
    )
    vim.keymap.set(
      'n',
      ']b',
      '<cmd>BufferRingForward<cr>',
      { desc = 'Next buffer' }
    )
  end,
}
