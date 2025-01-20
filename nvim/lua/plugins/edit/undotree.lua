vim.g.undotree_SetFocusWhenToggle = 1

return {
  'mbbill/undotree',
  keys = {
    { 'U', '<cmd>UndotreeToggle<cr>', desc = 'Show and focus undotree' }
  }
}
