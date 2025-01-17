return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  keys = {
    { '<leader>n', function() require('snacks.notifier').show_history() end, desc = 'Notification History' },
    { '<leader>c', function() require('snacks.bufdelete').delete() end,      desc = 'Close buffer' }
  },
  opts = {
    notifier = {
      enabled = true,
      top_down = false,
      timeout = 1000,
    },
    bufdelete = {
      enabled = true
    },
  }
}
