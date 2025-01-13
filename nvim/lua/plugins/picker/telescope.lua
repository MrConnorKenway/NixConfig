return {
  'nvim-telescope/telescope.nvim',
  keys = {
    {
      '<leader>fh',
      function() require('telescope.builtin').help_tags() end,
      desc = 'Telescope help tags'
    },
    {
      '<leader>S',
      function() require('telescope.builtin').lsp_document_symbols() end,
      desc = 'Telescope find document symbols'
    },
    {
      '<S-D-o>',
      function() require('telescope.builtin').lsp_document_symbols() end,
      desc =
      'Telescope find document symbols'
    },
    {
      '<leader>r',
      function() require('telescope.builtin').lsp_references() end,
      desc = 'Go to references'
    },
    {
      '<S-D-p>',
      function() require('telescope.builtin').commands() end,
      desc = 'Telescope find commands'
    },
    {
      'gd',
      function() require('telescope.builtin').lsp_definitions() end,
      desc = 'Go to definitions'
    },
    {
      'gy',
      function() require('telescope.builtin').lsp_type_definitions() end,
      desc = 'Go to type definitions'
    }
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope-ui-select.nvim',
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make', lazy = true }
  },
  config = function()
    require('telescope').setup {
      defaults = {
        mappings = {
          i = {
            ['<esc>'] = require('telescope.actions').close,
            ['<C-a>'] = function() vim.cmd('normal! I') end,
            ['<C-e>'] = function() vim.cmd('startinsert!') end,
            ['<C-f>'] = require('telescope.actions').results_scrolling_down,
            ['<C-b>'] = require('telescope.actions').results_scrolling_up
          }
        },
        sorting_strategy = 'ascending',
        layout_config = {
          horizontal = { prompt_position = 'top' },
          preview_cutoff = 120
        }
      }
    }
    require('telescope').load_extension('fzf')
  end
}
