-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out,                            'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.opt.list = true
vim.opt.listchars = { tab = '⇥ ', lead = '·', trail = '•', nbsp = '␣', multispace = '·' }
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.ignorecase = true
vim.opt.termguicolors = true
vim.opt.wildmode = 'full:longest'
vim.opt.smartcase = true

vim.g.mapleader = ' '

vim.keymap.set('n', '[b', '<cmd>bp<cr>', { desc = 'Navigate to previous buffer' })
vim.keymap.set('n', ']b', '<cmd>bn<cr>', { desc = 'Navigate to next buffer' })
vim.keymap.set('n', '<leader>w', '<cmd>q<cr>', { desc = 'Close window' })
vim.keymap.set('n', '<leader>q', '<cmd>qa<cr>', { desc = 'Quit' })

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
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = true
  },
  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on lua files
    config = function()
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
    opts = {
      labels = 'asdfjkl;',
      label = {
        rainbow = { enabled = true }
      }
    },
    keys = {
      { 's',     mode = { 'n', 'x', 'o' }, function() require('flash').jump() end,              desc = 'Flash' },
      { 'S',     mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end,        desc = 'Flash Treesitter' },
      { 'r',     mode = 'o',               function() require('flash').remote() end,            desc = 'Remote Flash' },
      { 'R',     mode = { 'o', 'x' },      function() require('flash').treesitter_search() end, desc = 'Treesitter Search' },
      { '<c-s>', mode = { 'c' },           function() require('flash').toggle() end,            desc = 'Toggle Flash Search' }
    }
  },
  {
    'RRethy/vim-illuminate',
    config = function()
      require('illuminate').configure {
        providers = { 'lsp' },
        min_count_to_highlight = 2
      }
    end
  },
  {
    'rmagatti/goto-preview',
    keys = {
      { 'gp', mode = { 'n' }, function() require('goto-preview').goto_preview_definition() end, desc = 'Preview LSP definition' }
    },
    config = true
  },
  {
    'echasnovski/mini.bufremove',
    keys = {
      { '<leader>c', mode = { 'n' }, function() require('mini.bufremove').delete() end, desc = 'Close buffer' }
    }
  },
  {
    'nvim-treesitter/nvim-treesitter',
    config = function()
      require('nvim-treesitter.configs').setup {
        auto_install = false,
        sync_install = false,
        highlight = { enable = false },
        indent = { enable = false },
        ensure_installed = {
          'c', 'lua', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline',
          'nix', 'asm', 'cpp', 'make', 'python', 'bash', 'rust', 'zig'
        },
        -- textobjects = {
        --   select = {
        --     enable = true,
        --     lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
        --     keymaps = {
        --       -- You can use the capture groups defined in textobjects.scm
        --       ['aa'] = '@parameter.outer',
        --       ['ia'] = '@parameter.inner',
        --       ['af'] = '@function.outer',
        --       ['if'] = '@function.inner',
        --       ['ac'] = '@class.outer',
        --       ['ic'] = '@class.inner',
        --     },
        --   },
        --   move = {
        --     enable = true,
        --     set_jumps = true, -- whether to set jumps in the jumplist
        --     goto_next_start = {
        --       [']m'] = '@function.outer',
        --       [']]'] = '@class.outer',
        --       [']l'] = '@loop.outer'
        --     },
        --     goto_next_end = {
        --       [']M'] = '@function.outer',
        --       [']['] = '@class.outer',
        --       [']L'] = '@loop.outer'
        --     },
        --     goto_previous_start = {
        --       ['[m'] = '@function.outer',
        --       ['[['] = '@class.outer',
        --       ['[l'] = '@loop.outer'
        --     },
        --     goto_previous_end = {
        --       ['[M'] = '@function.outer',
        --       ['[]'] = '@class.outer',
        --       ['[L'] = '@loop.outer'
        --     },
        --   }
        -- }
      }
    end
  },
  {
    'AstroNvim/astrotheme',
    priority = 1000,
    init = function()
      require('astrotheme').setup {
        palette = 'astrodark',
        plugin_default = false
      }
      vim.cmd.colorscheme 'astrotheme'
    end
  },
  {
    'rmagatti/auto-session',
    lazy = false,
    config = function()
      require('auto-session').setup {}
    end
  },
  {
    'akinsho/toggleterm.nvim',
    keys = {
      { '<leader>t', function() require('toggleterm').toggle(nil, nil, nil, 'float', nil) end, desc = 'Toggle floating terminal' },
      { '<C-`>',     function() require('toggleterm').toggle() end,                            mode = { 'n', 'o', 'x', 't', 'i', 'v' }, desc = 'Toggle terminal' },
      { '<M-J>',     function() require('toggleterm').toggle() end,                            mode = { 'n', 'o', 'x', 't', 'i', 'v' }, desc = 'Toggle terminal' }
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
  { 'nvim-tree/nvim-web-devicons',              lazy = true },
  {
    'prichrd/netrw.nvim',
    config = function()
      require('netrw').setup()
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
      lspconfig.clangd.setup {}
      lspconfig.nixd.setup {}
      lspconfig.lua_ls.setup {}
      lspconfig.pylsp.setup {}
    end
  },
  {
    'stevearc/conform.nvim',
    config = function()
      require('conform').setup({
        formatters_by_ft = {
          c = { 'clang-format' }
        },
        format_after_save = {
          lsp_format = 'fallback'
        }
      })
    end
  },
  {
    'nvim-lualine/lualine.nvim',
    opts = function(_)
      local icons = {
        misc = {
          dots = '󰇘',
        },
        ft = {
          octo = '',
        },
        diagnostics = {
          Error = ' ',
          Warn  = ' ',
          Hint  = ' ',
          Info  = ' ',
        },
        git = {
          added    = ' ',
          modified = ' ',
          removed  = ' ',
        },
        kinds = {
          Array         = ' ',
          Boolean       = '󰨙 ',
          Class         = ' ',
          Codeium       = '󰘦 ',
          Color         = ' ',
          Control       = ' ',
          Collapsed     = ' ',
          Constant      = '󰏿 ',
          Constructor   = ' ',
          Copilot       = ' ',
          Enum          = ' ',
          EnumMember    = ' ',
          Event         = ' ',
          Field         = ' ',
          File          = ' ',
          Folder        = ' ',
          Function      = '󰊕 ',
          Interface     = ' ',
          Key           = ' ',
          Keyword       = ' ',
          Method        = '󰊕 ',
          Module        = ' ',
          Namespace     = '󰦮 ',
          Null          = ' ',
          Number        = '󰎠 ',
          Object        = ' ',
          Operator      = ' ',
          Package       = ' ',
          Property      = ' ',
          Reference     = ' ',
          Snippet       = ' ',
          String        = ' ',
          Struct        = '󰆼 ',
          TabNine       = '󰏚 ',
          Text          = ' ',
          TypeParameter = ' ',
          Unit          = ' ',
          Value         = ' ',
          Variable      = '󰀫 ',
        },
      }

      return {
        options = {
          theme = 'auto',
          globalstatus = true,
          disabled_filetypes = { statusline = { 'dashboard', 'lazy', 'alpha', 'grapple' } },
          component_separators = '',
          section_separators = '',
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'grapple' },
          lualine_c = {},
          lualine_x = {
            {
              function()
                return require('noice').api.status.mode.get()
              end,
              cond = function()
                return package.loaded['noice'] and require('noice').api.status.mode.has()
              end,
            },
            {
              'diff',
              symbols = {
                added = icons.git.added,
                modified = icons.git.modified,
                removed = icons.git.removed,
              },
            },
            {
              'branch',
              fmt = function(str)
                return string.sub(str, 1, 12)
              end,
            },
          },
          lualine_y = {
            'location',
            { 'filetype', icons_enabled = true },
          },
          lualine_z = {
            { 'filename', file_status = true },
          },
        },
      }
    end,
  },
  {
    'mrjones2014/smart-splits.nvim',
    keys = {
      { '<C-h>', mode = { 'n', 'i', 't' }, '<cmd>SmartCursorMoveLeft<cr>',  desc = 'Move cursort left' },
      { '<C-j>', mode = { 'n', 'i', 't' }, '<cmd>SmartCursorMoveDown<cr>',  desc = 'Move cursort down' },
      { '<C-k>', mode = { 'n', 'i', 't' }, '<cmd>SmartCursorMoveUp<cr>',    desc = 'Move cursort up' },
      { '<C-l>', mode = { 'n', 'i', 't' }, '<cmd>SmartCursorMoveRight<cr>', desc = 'Move cursort right' },
      { '<M-h>', mode = { 'n', 'i', 't' }, '<cmd>SmartResizeLeft<cr>',      desc = 'Resize window left' },
      { '<M-j>', mode = { 'n', 'i', 't' }, '<cmd>SmartResizeDown<cr>',      desc = 'Resize window down' },
      { '<M-k>', mode = { 'n', 'i', 't' }, '<cmd>SmartResizeUp<cr>',        desc = 'Resize window up' },
      { '<M-l>', mode = { 'n', 'i', 't' }, '<cmd>SmartResizeRight<cr>',     desc = 'Resize window right' }
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
      { '<leader>ff', function() require('telescope.builtin').find_files() end,                    desc = 'Telescope find files' },
      { '<leader>fo', function() require('telescope.builtin').oldfiles() end,                      desc = 'Telescope find old files' },
      { '<leader>fg', function() require('telescope.builtin').live_grep() end,                     desc = 'Telescope live grep' },
      { '<leader>fb', function() require('telescope.builtin').buffers() end,                       desc = 'Telescope buffers' },
      { '<leader>fh', function() require('telescope.builtin').help_tags() end,                     desc = 'Telescope help tags' },
      { '<leader>fs', function() require('telescope.builtin').lsp_dynamic_workspace_symbols() end, desc = 'Telescope find workspace symbols' },
      { '<leader>fS', function() require('telescope.builtin').lsp_document_symbols() end,          desc = 'Telescope find document symbols' },
      { '<leader>go', function() require('telescope.builtin').git_status() end,                    desc = 'Telescope preview git status' },
      { '<leader>r',  function() require('telescope.builtin').lsp_references() end,                desc = 'Go to references' },
      { '<leader>h',  function() require('telescope.builtin').command_history() end,               desc = 'Telescope find files' },
      { 'gd',         function() require('telescope.builtin').lsp_definitions() end,               desc = 'Go to definitions' },
      { 'gy',         function() require('telescope.builtin').lsp_type_definitions() end,          desc = 'Go to type definitions' }
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
        'gzip', 'tarPlugin', 'tohtml', 'zipPlugin', 'syntax', 'tutor'
      }
    }
  }
})

vim.keymap.set('n', '<leader>l', function() require('lazy.view').show('home') end, { desc = 'Display lazy' })
