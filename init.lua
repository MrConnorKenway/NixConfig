vim.opt.list = true
vim.opt.listchars = { tab = '⇥ ', lead = '·', trail = '•', nbsp = '␣', multispace = '·' }
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.ignorecase = true
vim.opt.termguicolors = true
vim.opt.wildmode = 'full:longest'
vim.opt.smartcase = true

vim.g.mapleader = ' '

vim.api.nvim_create_autocmd('BufRead', {
  callback = function(opts)
    vim.api.nvim_create_autocmd('BufWinEnter', {
      once = true,
      buffer = opts.buf,
      callback = function()
        local ft = vim.bo[opts.buf].filetype
        local last_known_line = vim.api.nvim_buf_get_mark(opts.buf, '"')[1]
        if
          not (ft:match('commit') and ft:match('rebase'))
          and last_known_line > 1
          and last_known_line <= vim.api.nvim_buf_line_count(opts.buf)
        then
          vim.api.nvim_feedkeys([[g`"]], 'nx', false)
        end
      end,
    })
  end,
})

require('lazy').setup({
  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on lua files
    config = function ()
      require('lazydev').setup()
    end
  },
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      local gitsigns = require('gitsigns')
      gitsigns.setup()
      vim.keymap.set('n', ']c', function() gitsigns.nav_hunk('next') end, { desc = 'Go to next git change' })
      vim.keymap.set('n', '[c', function() gitsigns.nav_hunk('prev') end, { desc = 'Go to previous git change' })
      vim.keymap.set('n', '<leader>p', gitsigns.preview_hunk_inline, { desc = 'Git preview hunk' })
      vim.keymap.set('n', '<leader>u', gitsigns.reset_hunk, { desc = 'Git reset hunk' })
      vim.keymap.set('n', '<leader>b', gitsigns.blame_line, { desc = 'Git blame inline' })
    end
  },
  {
    'folke/flash.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter'
    },
    keys = {
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash' },
      { 'S', mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter' },
      { 'r', mode = 'o', function() require('flash').remote() end, desc = 'Remote Flash' },
      { 'R', mode = { 'o', 'x' }, function() require('flash').treesitter_search() end, desc = 'Treesitter Search' },
      { '<c-s>', mode = { 'c' }, function() require('flash').toggle() end, desc = 'Toggle Flash Search' }
    }
  },
  {
    'nvim-treesitter/nvim-treesitter',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects'
    },
    config = function()
      require('nvim-treesitter.configs').setup {
        auto_install = false,
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },
        ensure_installed = {
          'c', 'lua', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline',
          'nix', 'asm', 'cpp', 'make', 'python', 'bash', 'rust', 'zig'
        },
        textobjects = {
          select = {
            enable = true,
            lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ['aa'] = '@parameter.outer',
              ['ia'] = '@parameter.inner',
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              ['ic'] = '@class.inner',
            },
          },
          move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
              [']m'] = '@function.outer',
              [']]'] = '@class.outer',
              [']l'] = '@loop.outer'
            },
            goto_next_end = {
              [']M'] = '@function.outer',
              [']['] = '@class.outer',
              [']L'] = '@loop.outer'
            },
            goto_previous_start = {
              ['[m'] = '@function.outer',
              ['[['] = '@class.outer',
              ['[l'] = '@loop.outer'
            },
            goto_previous_end = {
              ['[M'] = '@function.outer',
              ['[]'] = '@class.outer',
              ['[L'] = '@loop.outer'
            },
          }
        }
      }
    end
  },
  {
    'navarasu/onedark.nvim',
    priority = 1000,
    lazy = false,
    init = function()
      require('onedark').setup {
        style = 'darker'
      }
      require('onedark').load()
    end
  },
  {
    'karb94/neoscroll.nvim',
    config = function ()
      local neoscroll = require('neoscroll')

      neoscroll.setup {
        easing = 'quadratic'
      }

      local keymap = {
        ["<C-u>"] = function() neoscroll.ctrl_u({ duration = 100 }) end;
        ["<C-d>"] = function() neoscroll.ctrl_d({ duration = 100 }) end;
        ["<C-b>"] = function() neoscroll.ctrl_b({ duration = 120 }) end;
        ["<C-f>"] = function() neoscroll.ctrl_f({ duration = 120 }) end;
        ["<C-y>"] = function() neoscroll.scroll(-0.1, { move_cursor=false; duration = 70 }) end;
        ["<C-e>"] = function() neoscroll.scroll(0.1, { move_cursor=false; duration = 70 }) end;
        ["zt"]    = function() neoscroll.zt({ half_win_duration = 80 }) end;
        ["zz"]    = function() neoscroll.zz({ half_win_duration = 80 }) end;
        ["zb"]    = function() neoscroll.zb({ half_win_duration = 80 }) end;
      }
      local modes = { 'n', 'v', 'x' }
      for key, func in pairs(keymap) do
        vim.keymap.set(modes, key, func)
      end
    end
  },
  {
    'akinsho/toggleterm.nvim',
    keys = {
      { '<leader>t', function() vim.cmd([[ToggleTerm direction='float']]) end, desc = 'Toggle floating terminal' },
      { '<C-`>', '<cmd>ToggleTerm<cr>', mode = { 'n', 'o', 'x', 't', 'i', 'v' }, desc = 'Toggle terminal' }
    },
    config = function()
      require('toggleterm').setup {
        size = 16,
        shading_factor = 2,
        float_opts = { border = 'rounded' }
      }
    end
  },
  {
    'nmac427/guess-indent.nvim',
    config = function()
      require('guess-indent').setup()
    end
  },
  { 'nvim-tree/nvim-web-devicons', lazy = true },
  {
    'prichrd/netrw.nvim',
    config = function()
      require('netrw').setup()
    end
  },
  {
    'nvim-lualine/lualine.nvim',
    config = function()
      require('lualine').setup()
    end
  },
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-cmdline'
    },
    event = 'UIEnter',
    config = function()
      local cmp = require('cmp')
      cmp.setup {
        sources = {
          { name = 'nvim_lsp' }
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered()
        },
        mapping = cmp.mapping.preset.insert {
          ['<cr>'] = cmp.mapping.confirm { select = true },
          ['<tab>'] = cmp.mapping.confirm { select = true },
          ['<C-e>'] = cmp.mapping.abort(),
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-p>'] = cmp.mapping.select_prev_item()
        },
        matching = {
          disallow_partial_matching = false,
          disallow_prefix_unmatching = true,
          disallow_fuzzy_matching = true,
          disallow_fullfuzzy_matching = true,
          disallow_partial_fuzzy_matching = true,
          disallow_symbol_nonprefix_matching = true
        }
      }
      cmp.setup.cmdline(':', {
        sources = {
          { name = 'cmdline' }
        },
        window = {
          completion = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.cmdline(),
        matching = {
          disallow_partial_matching = false,
          disallow_prefix_unmatching = false,
          disallow_fuzzy_matching = false,
          disallow_fullfuzzy_matching = false,
          disallow_partial_fuzzy_matching = false,
          disallow_symbol_nonprefix_matching = false
        }
      })
    end
  },
  {
    'neovim/nvim-lspconfig',
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(event)
          vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, {
            border = 'rounded'
          })
          vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(vim.lsp.handlers.signature_help, {
            border = 'rounded'
          })

          vim.keymap.set('n', 'gh', vim.lsp.buf.hover, { desc = 'Go to type definitions' })
          vim.keymap.set('n', '<leader>i', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, { desc = 'Toggle LSP inlay hint' })
        end
      })

      local lspconfig = require('lspconfig')
      lspconfig.clangd.setup{}
      lspconfig.nixd.setup{}
      lspconfig.lua_ls.setup{}
      lspconfig.pylsp.setup{}
    end
  },
  {
    'mrjones2014/smart-splits.nvim',
    keys = {
      { '<C-h>', mode = { 'n', 'i', 't' }, '<cmd>SmartCursorMoveLeft<cr>', desc = 'Move cursort left' },
      { '<C-j>', mode = { 'n', 'i', 't' }, '<cmd>SmartCursorMoveDown<cr>', desc = 'Move cursort down' },
      { '<C-k>', mode = { 'n', 'i', 't' }, '<cmd>SmartCursorMoveUp<cr>', desc = 'Move cursort up' },
      { '<C-l>', mode = { 'n', 'i', 't' }, '<cmd>SmartCursorMoveRight<cr>', desc = 'Move cursort right' },
      { '<M-h>', mode = { 'n', 'i', 't' }, '<cmd>SmartResizeLeft<cr>', desc = 'Resize window left' },
      { '<M-j>', mode = { 'n', 'i', 't' }, '<cmd>SmartResizeDown<cr>', desc = 'Resize window down' },
      { '<M-k>', mode = { 'n', 'i', 't' }, '<cmd>SmartResizeUp<cr>', desc = 'Resize window up' },
      { '<M-l>', mode = { 'n', 'i', 't' }, '<cmd>SmartResizeRight<cr>', desc = 'Resize window right' }
    },
    config = function()
      require('smart-splits').setup {
        default_amount = 3
      }
    end
  },
  { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  {
    'nvim-telescope/telescope.nvim',
    keys = {
      { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Telescope find files' },
      { '<leader>fo', '<cmd>Telescope oldfiles<cr>', desc = 'Telescope find old files' },
      { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = 'Telescope live grep' },
      { '<leader>fb', '<cmd>Telescope buffers<cr>', desc = 'Telescope buffers' },
      { '<leader>fh', '<cmd>Telescope help_tags<cr>', desc = 'Telescope help tags' },
      { '<leader>fs', '<cmd>Telescope lsp_dynamic_workspace_symbols<cr>', desc = 'Telescope find workspace symbols' },
      { '<leader>fS', '<cmd>Telescope lsp_document_symbols<cr>', desc = 'Telescope find document symbols' },
      { '<leader>go', '<cmd>Telescope git_status<cr>', desc = 'Telescope preview git status' },
      { '<leader>r',  '<cmd>Telescope lsp_references<cr>', desc = 'Go to references' },
      { '<leader>h',  '<cmd>Telescope command_history<cr>', desc = 'Telescope find files' },
      { 'gd',         '<cmd>Telescope lsp_definitions<cr>', desc = 'Go to definitions' },
      { 'gy',         '<cmd>Telescope lsp_type_definitions<cr>', desc = 'Go to type definitions' }
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-ui-select.nvim',
      'nvim-telescope/telescope-fzf-native.nvim'
    },
    config = function()
      require('telescope').setup {
        defaults = {
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
}, {
  ui = {
    border = 'rounded'
  },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip', 'tarPlugin', 'tohtml', 'zipPlugin', 'syntax'
      }
    }
  }
})

vim.keymap.set('n', '<leader>l', function() vim.cmd('Lazy home') end, { desc = 'Display lazy' })

