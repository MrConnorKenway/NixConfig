---@type LazyPluginSpec
return {
  'chentoast/marks.nvim',
  event = 'VeryLazy',
  keys = {
    {
      '<leader>m',
      function()
        require('marks').mark_state:all_to_list('quickfixlist')
        require('snacks.picker').qflist()
      end,
      desc = 'Show all marks in all buffers',
    },
  },
  opts = {
    excluded_buftypes = {
      'nofile',
      'git',
      'gitcommit',
      'gitrebase',
      'terminal',
      'fugitive',
      'floggraph',
    },
  },
}
