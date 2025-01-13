return {
  'tpope/vim-dispatch',
  keys = {
    { '`<Space>', ':Dispatch ',     desc = 'Dispatch command to run and return results in quickfix' },
    { "'<Space>", ':Start ',        desc = 'Start an eval process in a new focused window' },
    { '``',       '<cmd>Start<cr>', desc = 'Start a shell in a new focused window' },
  },
  init = function()
    vim.g.dispatch_no_maps = 1
  end
}
