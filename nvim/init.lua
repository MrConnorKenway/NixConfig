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
vim.opt.number = true
vim.opt.ignorecase = true
vim.opt.termguicolors = true
vim.opt.wildmode = 'full:longest'
vim.opt.smartcase = true
vim.opt.showmode = false

vim.lsp.set_log_level('off')

vim.g.mapleader = ' '

if os.getenv('SSH_TTY') ~= nil then
  local function paste()
    return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') }
  end
  local osc52 = require('vim.ui.clipboard.osc52')
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = osc52.copy('+'),
      ['*'] = osc52.copy('*')
    },
    paste = {
      ['+'] = paste,
      ['*'] = paste,
    }
  }
end

vim.keymap.set('n', '[b', '<cmd>bp<cr>', { desc = 'Navigate to previous buffer' })
vim.keymap.set('n', ']b', '<cmd>bn<cr>', { desc = 'Navigate to next buffer' })
vim.keymap.set('n', 'q', function()
  if vim.bo.filetype == 'DiffviewFiles' then
    require('diffview').close()
  elseif vim.bo.filetype == 'toggleterm' then
    vim.cmd('startinsert')
  else
    vim.cmd('q')
  end
end, { desc = 'Close window' })
vim.keymap.set('n', '<leader>w', '<cmd>wa<cr>', { desc = 'Save workspace without quit' })
vim.keymap.set('n', '<leader>x', '<cmd>xa<cr>', { desc = 'Save and quit workspace' })
vim.keymap.set('n', '<leader>q', '<cmd>qa<cr>', { desc = 'Quit workspace without save' })
vim.keymap.set('v', '<leader>c', '"+y', { desc = 'Navigate to previous buffer' })

-- copy from https://github.com/neovim/neovim/pull/28176/files#diff-49225a49c226c2f1b36f966d0178c556e204cdc0b660c80db9e4568e03f6ef99R126
-- WARN: may change as neovim updates
vim.keymap.set('n', '<C-/>', function() return require('vim._comment').operator() .. '_' end,
  { expr = true, desc = 'Comment current line' })
vim.keymap.set('n', '<D-/>', function() return require('vim._comment').operator() .. '_' end,
  { expr = true, desc = 'Comment current line' })
vim.keymap.set('v', '<C-/>', function() return require('vim._comment').operator() end,
  { expr = true, desc = 'Comment current block' })
vim.keymap.set('v', '<D-/>', function() return require('vim._comment').operator() end,
  { expr = true, desc = 'Comment current block' })


local function autocmd(events, ...)
  vim.api.nvim_create_autocmd(events, { callback = ... })
end

autocmd('BufRead', function(opts)
  vim.api.nvim_create_autocmd('BufWinEnter', {
    once = true,
    buffer = opts.buf,
    callback = function()
      local ft = vim.bo[opts.buf].filetype
      local last_known_line = vim.api.nvim_buf_get_mark(opts.buf, '"')[1]
      if
          not (ft:match('gitcommit') or ft:match('gitrebase'))
          and last_known_line > 1
          and last_known_line <= vim.api.nvim_buf_line_count(opts.buf)
      then
        vim.api.nvim_feedkeys([[g`"]], 'nx', false)
      end
    end,
  })
end)

autocmd({ 'VimEnter', 'WinEnter', 'BufWinEnter' }, function()
  if vim.o.number then
    vim.opt.cursorline = true
    vim.opt.signcolumn = 'yes'
  end
end)

autocmd({ 'WinLeave' }, function()
  vim.opt.cursorline = false
end)

require('lazy').setup({
  require('heirline.config'),
  {
    'sindrets/diffview.nvim',
    keys = {
      {
        '<leader>d',
        mode = { 'n' },
        function()
          require('diffview').open({ '-uno' }) -- hide untracked files
        end,
        desc = 'Open git diffview'
      }
    }
  },
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
      gitsigns.setup {
        sign_priority = 100,
        preview_config = {
          border = 'rounded'
        }
      }
      vim.keymap.set('n', ']c', function() gitsigns.nav_hunk('next') end, { desc = 'Go to next git change' })
      vim.keymap.set('n', '[c', function() gitsigns.nav_hunk('prev') end, { desc = 'Go to previous git change' })
      vim.keymap.set('n', '<leader>u', gitsigns.reset_hunk, { desc = 'Git reset hunk' })
      vim.keymap.set('n', '<leader>b', gitsigns.blame_line, { desc = 'Git blame inline' })
      vim.keymap.set('n', '<leader>a', gitsigns.stage_hunk, { desc = 'Git stage hunk' })
    end
  },
  {
    'folke/flash.nvim',
    event = 'UIEnter',
    dependencies = {
      'nvim-treesitter/nvim-treesitter'
    },
    opts = {
      labels = 'asdfjkl;weionmcvgh'
    },
    keys = {
      { 's',     mode = { 'n', 'x', 'o' }, function() require('flash').jump() end,                                                          desc = 'Flash' },
      { 'S',     mode = { 'n', 'x', 'o' }, function() require('flash').treesitter({ label = { rainbow = { enabled = true } } }) end,        desc = 'Flash Treesitter' },
      { 'r',     mode = 'o',               function() require('flash').remote() end,                                                        desc = 'Remote Flash' },
      { 'R',     mode = { 'o', 'x' },      function() require('flash').treesitter_search({ label = { rainbow = { enabled = true } } }) end, desc = 'Treesitter Search' },
      { '<c-s>', mode = { 'c' },           function() require('flash').toggle() end,                                                        desc = 'Toggle Flash Search' }
    }
  },
  {
    'RRethy/vim-illuminate',
    event = 'LspAttach',
    config = function()
      require('illuminate').configure {
        providers = { 'lsp' }
      }
    end
  },
  {
    'rmagatti/goto-preview',
    keys = {
      { 'gp', mode = { 'n' }, function() require('goto-preview').goto_preview_definition {} end, desc = 'Preview LSP definition in popup' },
      { 'gr', mode = { 'n' }, function() require('goto-preview').goto_preview_references {} end, desc = 'Preview LSP references in popup' },
    },
    config = function()
      require('goto-preview').setup {
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' }
      }
    end
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
        modules = {},
        ignore_install = {},
        auto_install = false,
        sync_install = false,
        highlight = { enable = false },
        indent = { enable = false },
        ensure_installed = {
          'c', 'lua', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline',
          'nix', 'asm', 'cpp', 'make', 'python', 'bash', 'rust', 'zig'
        }
      }

      local treesitter_highlight_namespace = vim.api.nvim_create_namespace('treesitter.navigator.highlight')
      local ts_utils = require('nvim-treesitter.ts_utils')
      local node = nil

      local on_cursor_moved = function(info)
        if not node then
          vim.api.nvim_buf_clear_namespace(0, treesitter_highlight_namespace, 0, -1)
          vim.api.nvim_del_autocmd(info.id)
          return
        end

        local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
        local start_row, start_col, end_row, end_col = ts_utils.get_vim_range { node:range() }

        if (crow ~= start_row or ccol ~= start_col - 1) and (crow ~= end_row or ccol ~= end_col - 1) then
          vim.api.nvim_buf_clear_namespace(0, treesitter_highlight_namespace, start_row - 1, end_row)
          vim.api.nvim_del_autocmd(info.id)
          node = nil
        end
      end

      vim.keymap.set('n', '<M-o>', function()
        local start_row, start_col, end_row, end_col

        if node == nil then
          node = vim.treesitter.get_node()
          if node == nil then
            return
          end
          vim.cmd("normal! m'") -- add to jump list
        end

        if node:parent() ~= nil then
          node = node:parent()
        end

        start_row, start_col, end_row, end_col = ts_utils.get_vim_range { node:range() }
        vim.api.nvim_win_set_cursor(0, { start_row, start_col - 1 }) -- `nvim_win_set_cursor` requires (1, 0) indexed (row, col)
        vim.api.nvim_buf_set_extmark(0, treesitter_highlight_namespace, start_row - 1, start_col - 1,
          { end_row = end_row - 1, end_col = end_col, hl_group = 'Visual' })

        for i = start_row, end_row - 1 do
          if vim.api.nvim_buf_get_lines(0, i, i + 1, false)[1]:len() == 0 then
            vim.api.nvim_buf_set_extmark(0, treesitter_highlight_namespace, i, 0,
              {
                virt_text = { { ' ', 'Visual' } },
                virt_text_win_col = 0
              })
          end
        end

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, { callback = on_cursor_moved })
      end, { desc = 'Go to start of parent syntax tree node' })

      vim.keymap.set('n', '<M-O>', function()
        local start_row, start_col, end_row, end_col

        if node == nil then
          node = vim.treesitter.get_node()
          if node == nil then
            return
          end
          vim.cmd("normal! m'") -- add to jump list
        end

        if node:parent() ~= nil then
          node = node:parent()
        end

        start_row, start_col, end_row, end_col = ts_utils.get_vim_range { node:range() }
        vim.api.nvim_win_set_cursor(0, { end_row, end_col - 1 }) -- `nvim_win_set_cursor` requires (1, 0) indexed (row, col)
        vim.api.nvim_buf_set_extmark(0, treesitter_highlight_namespace, start_row - 1, start_col - 1,
          { end_row = end_row - 1, end_col = end_col, hl_group = 'Visual' })

        for i = start_row, end_row - 1 do
          if vim.api.nvim_buf_get_lines(0, i, i + 1, false)[1]:len() == 0 then
            vim.api.nvim_buf_set_extmark(0, treesitter_highlight_namespace, i, 0,
              {
                virt_text = { { ' ', 'Visual' } },
                virt_text_win_col = 0
              })
          end
        end

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, { callback = on_cursor_moved })
      end, { desc = 'Go to end of parent syntax tree node' })
    end
  },
  {
    'catppuccin/nvim',
    priority = 1000,
    lazy = false,
    init = function()
      vim.cmd.colorscheme('catppuccin-mocha')
    end
  },
  {
    'rmagatti/auto-session',
    lazy = false,
    config = function()
      require('auto-session').setup {
        session_lens = {
          load_on_setup = false
        }
      }

      vim.keymap.set('n', '<leader>j', '<cmd>SessionSearch<cr>', { desc = 'Session Search' })
    end
  },
  {
    'stevearc/dressing.nvim',
    event = 'UIEnter'
  },
  {
    'akinsho/toggleterm.nvim',
    keys = {
      {
        '<leader>t',
        function() require('toggleterm').toggle(nil, nil, nil, 'float', nil) end,
        desc = 'Toggle floating terminal'
      },
      {
        '<D-j>',
        function() require('toggleterm').toggle() end,
        mode = { 'n', 'o', 'x', 't', 'i', 'v' },
        desc = 'Toggle terminal'
      },
      {
        '<C-`>',
        function() require('toggleterm').toggle() end,
        mode = { 'n', 'o', 'x', 't', 'i', 'v' },
        desc = 'Toggle terminal'
      }
    },
    config = function()
      require('toggleterm').setup {
        size = 16,
        shade_terminals = true,
        float_opts = { border = 'rounded' },
        on_create = function()
          local vsplit_term = function()
            local terminals = require('toggleterm.terminal').get_all()
            local idx = 0

            for _, t in pairs(terminals) do
              if idx < t.id then
                idx = t.id
              end
            end

            require('toggleterm').toggle(idx + 1)
          end

          vim.opt.cursorline = false

          vim.keymap.set({ 'n', 't' }, [[<M-\>]], vsplit_term, { desc = 'Split terminals in vertical', buffer = true })
          vim.keymap.set({ 'n', 't' }, [[<D-\>]], vsplit_term, { desc = 'Split terminals in vertical', buffer = true })
        end,
        persist_mode = false, -- always open terminal in insert mode
        close_on_exit = false,
        on_exit = function(term)
          term:close() -- hack toggleterm's normal exit procedure to prevent mode changing
          if vim.api.nvim_buf_is_loaded(term.bufnr) then
            vim.defer_fn(function() vim.api.nvim_buf_delete(term.bufnr, { force = true }) end, 10)
          end
        end
      }

      vim.keymap.set('t', '<C-s>', [[<C-\><C-n>]], { desc = 'Exit to terminal normal mode' })
    end
  },
  {
    'nmac427/guess-indent.nvim',
    config = function()
      require('guess-indent').setup {}
    end
  },
  { 'nvim-tree/nvim-web-devicons' },
  {
    'prichrd/netrw.nvim',
    ft = 'netrw', -- only load on netrw files
    config = function()
      require('netrw').setup()
    end
  },
  {
    'junegunn/fzf',
    lazy = true,
    build = './install --bin',
    enabled = function()
      return vim.fn.executable('fzf') == 0
    end
  },
  {
    'ibhagwan/fzf-lua',
    keys = {
      { '<leader>o',  function() require('fzf-lua').files() end,                      desc = 'FzfLua find files' },
      {
        '<leader>O',
        function() require('fzf-lua').files { cwd = vim.fn.expand('%:h') } end,
        desc = 'FzfLua find files in directory of current buffer'
      },
      { '<leader>fg', function() require('fzf-lua').live_grep_native() end,           desc = 'FzfLua live grep' },
      { '<S-D-f>',    function() require('fzf-lua').live_grep_native() end,           desc = 'FzfLua live grep' },
      { '<S-M-f>',    function() require('fzf-lua').live_grep_native() end,           desc = 'FzfLua live grep' },
      { '<leader>s',  function() require('fzf-lua').lsp_live_workspace_symbols() end, desc = 'FzfLua find workspace symbols' },
    },
    dependencies = { 'nvim-tree/nvim-web-devicons', 'junegunn/fzf' },
    config = function()
      require('fzf-lua').setup {
        'default-title',
        files = {
          git_icons = false
        },
        winopts = {
          preview = {
            default = 'bat_native',
            delay = 100
          }
        },
        previewers = {
          builtin = {
            treesitter = { enable = true }
          }
        },
        keymap = {
          builtin = {
            true,
            ['<C-u>'] = 'preview-half-page-up',
            ['<C-d>'] = 'preview-half-page-down',
            ['F9'] = 'toggle-preview'
          },
          fzf = {
            true,
            ['Ctrl-u'] = 'preview-half-page-up',
            ['Ctrl-d'] = 'preview-half-page-down',
            ['F9'] = 'toggle-preview'
          }
        }
      }
    end
  },
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-cmdline'
    },
    event = { 'InsertEnter', 'CmdlineEnter' },
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
    'williamboman/mason.nvim',
    config = true
  },
  {
    'SmiteshP/nvim-navic',
    config = function()
      require('nvim-navic').setup {
        icons = {
          File = ' ',
          Module = ' ',
          Namespace = ' ',
          Package = ' ',
          Class = ' ',
          Method = ' ',
          Property = ' ',
          Field = ' ',
          Constructor = ' ',
          Enum = ' ',
          Interface = ' ',
          Function = '󰊕 ',
          Variable = '󰫧 ',
          Constant = ' ',
          String = ' ',
          Number = ' ',
          Boolean = ' ',
          Array = ' ',
          Object = ' ',
          Key = ' ',
          Null = ' ',
          EnumMember = ' ',
          Struct = ' ',
          Event = ' ',
          Operator = ' ',
          TypeParameter = ' '
        },
        lsp = {
          auto_attach = true,
          preference = nil,
        },
        highlight = true,
        separator = ' > ',
        depth_limit = 0,
        depth_limit_indicator = '..',
        safe_output = true,
        lazy_update_context = false,
        click = false,
        format_text = function(text)
          return text
        end,
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

          vim.keymap.set('n', 'gh', vim.lsp.buf.hover, { desc = 'Display LSP hover' })
          vim.keymap.set('n', '<leader>i', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, { desc = 'Toggle LSP inlay hint' })
          vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, { desc = 'LSP Rename' })

          local signs = { Error = ' ', Warn = ' ', Hint = ' ', Info = ' ' }
          for type, icon in pairs(signs) do
            local hl = 'DiagnosticSign' .. type
            vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
          end
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
    event = 'BufWritePre',
    keys = {
      {
        '<leader>f',
        mode = 'v',
        function()
          require('conform').format({ async = true }, function(err)
            if not err then
              local mode = vim.api.nvim_get_mode().mode
              if vim.startswith(string.lower(mode), 'v') then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true)
              end
            end
          end)
        end,
        desc = 'LSP range format'
      },
    },
    config = function()
      require('conform').setup({
        formatters_by_ft = {
          c = { 'clang-format' }
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_format = 'fallback'
        }
      })
    end
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
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make',
    lazy = true
  },
  {
    'nvim-telescope/telescope.nvim',
    keys = {
      { '<leader>p',  function() require('telescope.builtin').buffers() end,              desc = 'Telescope buffers' },
      { '<D-p>',      function() require('telescope.builtin').buffers() end,              desc = 'Telescope buffers' },
      { '<leader>fh', function() require('telescope.builtin').help_tags() end,            desc = 'Telescope help tags' },
      { '<leader>S',  function() require('telescope.builtin').lsp_document_symbols() end, desc = 'Telescope find document symbols' },
      { '<leader>r',  function() require('telescope.builtin').lsp_references() end,       desc = 'Go to references' },
      { '<leader>h',  function() require('telescope.builtin').command_history() end,      desc = 'Telescope find command history' },
      { '<S-D-p>',    function() require('telescope.builtin').commands() end,             desc = 'Telescope find commands' },
      { 'gd',         function() require('telescope.builtin').lsp_definitions() end,      desc = 'Go to definitions' },
      { 'gy',         function() require('telescope.builtin').lsp_type_definitions() end, desc = 'Go to type definitions' }
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-ui-select.nvim',
      'nvim-telescope/telescope-fzf-native.nvim'
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
