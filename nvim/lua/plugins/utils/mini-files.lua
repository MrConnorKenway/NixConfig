vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesWindowOpen',
  callback = function(args)
    local win_id = args.data.win_id
    vim.api.nvim_win_set_config(win_id, { border = "rounded" })
  end
})

return { 'echasnovski/mini.files',
  keys = {
    { '<leader>e', function() require('mini.files').open() end, desc = 'Open mini.files menu' }
  },
  opts = {}
}
