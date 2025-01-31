return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  keys = {
    {
      '<D-o>',
      mode = { 'n', 't', 'i' },
      function()
        require('snacks.picker').files({ matcher = { frecency = true } })
      end,
      desc = 'Picker find files'
    },
    {
      '<D-p>',
      mode = { 'n', 't', 'i' },
      function()
        require('snacks.picker').buffers {
          matcher = { frecency = true },
          current = false
        }
      end,
      desc = 'Picker switch buffers'
    },
    {
      '<S-D-f>',
      mode = { 'n', 't', 'i' },
      function() require('snacks.picker').grep() end,
      desc = 'Picker live grep'
    },
    {
      '<S-M-f>',
      mode = { 'n', 't', 'i' },
      function() require('snacks.picker').grep() end,
      desc = 'Picker live grep'
    },
    {
      '<D-t>',
      mode = { 'n', 'i' },
      function() require('snacks.picker').lsp_workspace_symbols() end,
      desc = 'Picker find workspace symbols'
    },
    {
      '<leader>s',
      function() require('snacks.picker').lsp_workspace_symbols() end,
      desc = 'Picker find workspace symbols'
    },
    {
      '<leader>h',
      function() require('snacks.picker').command_history() end,
      desc = 'Picker find command history'
    },
    {
      '<leader>S',
      function() require('snacks.picker').lsp_symbols() end,
      desc = 'Picker find document symbols'
    },
    {
      '<S-D-o>',
      function() require('snacks.picker').lsp_symbols() end,
      desc = 'Picker find document symbols'
    },
    {
      '<leader>r',
      function() require('snacks.picker').lsp_references() end,
      desc = 'Go to references'
    },
    {
      'gd',
      function() require('snacks.picker').lsp_definitions() end,
      desc = 'Go to definitions'
    },
    {
      'gy',
      function() require('snacks.picker').lsp_type_definitions() end,
      desc = 'Go to type definitions'
    },
    {
      '<leader>z',
      function()
        require('snacks.picker').zoxide()
      end,
      desc = 'Find files from zoxide'
    },
    {
      '<D-f>',
      mode = { 'n', 'i' },
      function() require('snacks.picker').lines() end,
      desc = 'Picker search current buffer'
    },
    {
      '<M-f>',
      mode = { 'n' },
      function() require('snacks.picker').lines() end,
      desc = 'Picker search current buffer'
    },
    {
      '<leader>n',
      function() require('snacks.notifier').show_history() end,
      desc = 'Notification History'
    },
    {
      '<leader>c',
      function() require('snacks.bufdelete').delete() end,
      desc = 'Close buffer'
    }
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
    picker = {
      enabled = true,
      win = {
        -- input window
        input = {
          keys = {
            ['<Esc>'] = { 'close', mode = { 'n', 'i' } },
            ['<C-w>'] = { '<c-s-w>', mode = { 'i' }, expr = true, desc = 'delete word' },
            ['<S-CR>'] = { { 'pick_win', 'jump' }, mode = { 'n', 'i' } },
            ['<C-Up>'] = { 'history_back', mode = { 'i', 'n' } },
            ['<C-Down>'] = { 'history_forward', mode = { 'i', 'n' } },
            ['<Tab>'] = { 'select_and_next', mode = { 'i', 'n' } },
            ['<S-Tab>'] = { 'select_and_prev', mode = { 'i', 'n' } },
            ['<Down>'] = { 'list_down', mode = { 'i', 'n' } },
            ['<Up>'] = { 'list_up', mode = { 'i', 'n' } },
            ['<c-n>'] = { 'list_down', mode = { 'i', 'n' } },
            ['<c-p>'] = { 'list_up', mode = { 'i', 'n' } },
            ['<c-u>'] = { 'preview_scroll_up', mode = { 'i', 'n' } },
            ['<c-f>'] = { 'list_scroll_down', mode = { 'i', 'n' } },
            ['<c-d>'] = { 'preview_scroll_down', mode = { 'i', 'n' } },
            ['<c-b>'] = { 'list_scroll_up', mode = { 'i', 'n' } },
            ['<c-a>'] = false
          },
          b = {
            minipairs_disable = true,
          },
        },
      },
      icons = {
        diagnostics = {
          Error = '',
          Warn  = '󰔶',
          Hint  = '',
          Info  = '',
        }
      }
    }
  }
}
