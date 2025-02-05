return {
  'luukvbaal/statuscol.nvim',
  init = function()
    vim.o.numberwidth = 2
  end,
  config = function()
    require('statuscol').setup {
      segments = {
        {
          sign = {
            namespace = { 'diagnostic/signs' },
            colwidth = 1,
          },
        },
        { text = { ' ' } },
        {
          text = {
            require('statuscol.builtin').lnumfunc,
          },
          click = 'v:lua.ScLa',
        },
        {
          sign = {
            namespace = { 'gitsigns+' },
            maxwidth = 1,
            colwidth = 1,
          },
          click = 'v:lua.ScSa',
        },
        { text = { ' ' } },
      },
      ft_ignore = {
        'help',
        'vim',
        'git',
        'fugitive',
        'noice',
        'lazy',
        'toggleterm',
        'floggraph',
      },
      bt_ignore = {
        'terminal',
        'nofile',
      },
    }
  end,
}
