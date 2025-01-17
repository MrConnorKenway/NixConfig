return {
  'stevearc/overseer.nvim',
  keys = {
    { '``',    '<cmd>OverseerRunCmd<cr>', desc = 'Overseer run command' },
    { '<D-r>', mode = { 'n', 'i' },       '<cmd>OverseerToggle<cr>',    desc = 'Overseer toggle task lists' }
  },
  config = function()
    require('overseer').setup {
      strategy = 'jobstart',
      task_list = {
        max_height = { 30, 0.5 },
        height = 12,
        bindings = {
          ['?'] = 'ShowHelp',
          ['<CR>'] = 'RunAction',
          ['<C-e>'] = 'Edit',
          ['<C-v>'] = false,
          ['<C-s>'] = false,
          ['<C-f>'] = false,
          ['<C-q>'] = 'OpenQuickFix',
          ['p'] = 'OpenFloat',
          ['<C-l>'] = false,
          ['<C-h>'] = false,
          ['L'] = 'IncreaseAllDetail',
          ['H'] = 'DecreaseAllDetail',
          ['['] = false,
          [']'] = false,
          ['<C-p>'] = 'PrevTask',
          ['<C-n>'] = 'NextTask',
          ['<C-k>'] = false,
          ['<C-j>'] = false,
          ['q'] = 'Close',
        }
      },
      task_editor = {
        bindings = {
          i = {
            ['<CR>'] = 'Submit',
            ['<C-c>'] = 'Cancel',
          },
          n = {
            ['<CR>'] = 'Submit',
            ['q'] = 'Cancel',
            ['?'] = 'ShowHelp',
          }
        }
      }
    }
  end
}

