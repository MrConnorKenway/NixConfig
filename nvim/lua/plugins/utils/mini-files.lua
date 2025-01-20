vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesWindowOpen',
  callback = function(args)
    local win_id = args.data.win_id
    vim.api.nvim_win_set_config(win_id, { border = "rounded" })
  end
})

return { 'echasnovski/mini.files',
  keys = {
    { '<leader>e', function() require('mini.files').open(vim.api.nvim_buf_get_name(0)) end, desc = 'Open mini.files menu at current file path' },
    { '<D-e>', function() require('mini.files').open(vim.api.nvim_buf_get_name(0)) end, desc = 'Open mini.files menu at current file path' },
    { '<leader>E', function() require('mini.files').open() end, desc = 'Open mini.files menu at CWD' },
    { '<S-D-e>', function() require('mini.files').open() end, desc = 'Open mini.files menu at CWD' },
  },
  opts = {
    mappings = {
      go_in = '<cr>',
      go_out = '-'
    }
  }
}
