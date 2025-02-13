---@type LazyPluginSpec
return {
  'landonb/vim-buffer-ring',
  event = 'VeryLazy',
  config = function()
    vim.keymap.set('n', '[b', '<cmd>BufferRingReverse<cr>', { desc = 'Previous quickfix' })
    vim.keymap.set('n', ']b', '<cmd>BufferRingForward<cr>', { desc = 'Next quickfix' })
  end
}
