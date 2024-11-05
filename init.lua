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
    "folke/flash.nvim",
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },
  {
    'nvim-treesitter/nvim-treesitter',
    config = function()
      require('nvim-treesitter.configs').setup {
        highlight = { enable = true },
        indent = { enable = true }
      }
    end
  },
  {
    'AstroNvim/astrotheme',
    priority = 1000,
    init = function()
      require('astrotheme').setup {
        palette = 'astrodark'
      }
      vim.cmd.colorscheme 'astrotheme'
    end
  },
  {
    'akinsho/toggleterm.nvim',
    keys = {
      { '<leader>t', function() vim.cmd([[ToggleTerm direction='float']]) end, desc = 'Toggle floating terminal' },
      { '<F9>', '<cmd>ToggleTerm<cr>', mode = { 'n', 'o', 'x', 't', 'i', 'v' }, desc = 'Toggle terminal' }
    },
    config = function()
      require('toggleterm').setup {
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
    'nvim-lualine/lualine.nvim',
    config = function()
      require('lualine').setup()
    end
  },
  {
    'hrsh7th/nvim-cmp',
    dependencies = { 'hrsh7th/cmp-nvim-lsp' },
    event = 'InsertEnter',
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
          disallow_fuzzy_matching = true
        }
      }
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
    'folke/which-key.nvim',
    event = 'VeryLazy',
    keys = {
      { '<leader>c', '<cmd>bd<cr>', desc = 'Close buffer' }
    }
  },
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
      { 'gd',         '<cmd>Telescope lsp_definitions<cr>', desc = 'Go to definitions' },
      { 'gy',         '<cmd>Telescope lsp_type_definitions<cr>', desc = 'Go to type definitions' }
    },
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope-ui-select.nvim' },
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
    end
  }
}, {
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip', 'netrwPlugin', 'tarPlugin', 'tohtml', 'zipPlugin', 'syntax'
      }
    }
  }
})
