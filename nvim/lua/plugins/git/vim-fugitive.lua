---@type LazyPluginSpec
return {
  'tpope/vim-fugitive',
  cmd = { 'G', 'Gread', 'Gclog' },
  keys = {
    { 'gv',        '<cmd>vertical G<cr>',                     desc = 'Git status vertical' },
    { 'gcc',       '<cmd>tab G commit --verbose<cr>',         desc = 'Git commit' },
    { 'gca',       '<cmd>tab G commit --verbose --amend<cr>', desc = 'Git commit' },
    { '<leader>d', '<cmd>Gdiffsplit<cr>',                     desc = 'Git diff' },
    { '<leader>D', '<cmd>Gvdiffsplit @:%<cr>',                desc = 'Git diff with staged' },
    { '<leader>g', ':G ',                                     desc = 'Git cmdline' }
  },
  init = function()
    vim.api.nvim_create_autocmd('FileType', {
      pattern = { 'fugitive', 'git' },
      callback = function()
        vim.keymap.set('n', '<C-p>', function() vim.api.nvim_feedkeys('(', 't', true) end, { buffer = true })
        vim.keymap.set('n', '<C-n>', function() vim.api.nvim_feedkeys(')', 't', true) end, { buffer = true })
      end
    })
  end
}
