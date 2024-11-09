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
vim.opt.relativenumber = true
vim.opt.signcolumn = 'yes'

vim.g.mapleader = ' '

vim.keymap.set('n', '[b', '<cmd>bp<cr>', { desc = 'Navigate to previous buffer' })
vim.keymap.set('n', ']b', '<cmd>bn<cr>', { desc = 'Navigate to next buffer' })
vim.keymap.set('n', '<leader>w', '<cmd>q<cr>', { desc = 'Close window' })
vim.keymap.set('n', 'q', '<cmd>q<cr>', { desc = 'Close window' })
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
        }
      }
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
      require('auto-session').setup {}
    end
  },
  { 'stevearc/dressing.nvim' },
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
  { 'nvim-tree/nvim-web-devicons', lazy = true },
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
          vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, { desc = 'LSP Rename' })
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
    'rebelot/heirline.nvim',
    config = function()
      local conditions = require('heirline.conditions')
      local utils = require('heirline.utils')

      local theme_colors = require('catppuccin.palettes').get_palette('mocha')

      local colors = {
        bright_bg = utils.get_highlight('Folded').bg,
        bright_fg = utils.get_highlight('Folded').fg,
        red = utils.get_highlight('DiagnosticError').fg,
        blue = utils.get_highlight('Function').fg,
        orange = utils.get_highlight('Constant').fg,
        purple = utils.get_highlight('Statement').fg,
        cyan = utils.get_highlight('Special').fg,
        diag_warn = utils.get_highlight('DiagnosticWarn').fg,
        diag_error = utils.get_highlight('DiagnosticError').fg,
        diag_hint = utils.get_highlight('DiagnosticHint').fg,
        diag_info = utils.get_highlight('DiagnosticInfo').fg,
        git_del = utils.get_highlight('GitSignsDelete').fg,
        git_add = utils.get_highlight('GitSignsAdd').fg,
        git_change = utils.get_highlight('GitSignsChange').fg,
      }

      require('heirline').load_colors(colors)

      local ViMode = {
        -- get vim current mode, this information will be required by the provider
        -- and the highlight functions, so we compute it only once per component
        -- evaluation and store it as a component attribute
        init = function(self)
          self.mode = vim.fn.mode(1) -- :h mode()
        end,
        -- Now we define some dictionaries to map the output of mode() to the
        -- corresponding string and color. We can put these into `static` to compute
        -- them at initialisation time.
        static = {
          mode_names = { -- change the strings if you like it vvvvverbose!
            n = 'NORMAL',
            no = 'N?',
            nov = 'N?',
            noV = 'N?',
            ['no\22'] = 'N?',
            niI = 'Ni',
            niR = 'Nr',
            niV = 'Nv',
            nt = 'Nt',
            v = 'VISUAL',
            vs = 'Vs',
            V = 'VISUAL LINE',
            Vs = 'Vs',
            ['\22'] = 'VISUAL BLOCK',
            ['\22s'] = '^V',
            s = 'S',
            S = 'S_',
            ['\19'] = '^S',
            i = 'INSERT',
            ic = 'Ic',
            ix = 'Ix',
            R = 'REPLACE',
            Rc = 'Rc',
            Rx = 'Rx',
            Rv = 'Rv',
            Rvc = 'Rv',
            Rvx = 'Rv',
            c = 'COMMAND',
            cv = 'Ex',
            r = '...',
            rm = 'M',
            ['r?'] = '?',
            ['!'] = '!',
            t = 'TERMINAL',
          },
          mode_bgs = {
            n = theme_colors.blue,
            i = theme_colors.green,
            v = theme_colors.mauve,
            V = theme_colors.mauve,
            ['\22'] = theme_colors.mauve,
            c = theme_colors.peach,
            s = 'purple',
            S = 'purple',
            ['\19'] = 'purple',
            R = theme_colors.red,
            r = theme_colors.red,
            ['!'] = 'red',
            t = theme_colors.green,
          }
        },
        -- We can now access the value of mode() that, by now, would have been
        -- computed by `init()` and use it to index our strings dictionary.
        -- note how `static` fields become just regular attributes once the
        -- component is instantiated.
        -- To be extra meticulous, we can also add some vim statusline syntax to
        -- control the padding and make sure our string is always at least 2
        -- characters long. Plus a nice Icon.
        provider = function(self)
          return ' %2(' .. self.mode_names[self.mode] .. '%) '
        end,
        -- Same goes for the highlight. Now the foreground will change according to the current mode.
        hl = function(self)
          local mode = self.mode:sub(1, 1) -- get only the first mode character
          return { fg = theme_colors.base, bg = self.mode_bgs[mode], bold = true }
        end,
        -- Re-evaluate the component only on ModeChanged event!
        -- Also allows the statusline to be re-evaluated when entering operator-pending mode
        update = {
          'ModeChanged',
          pattern = '*:*',
          callback = vim.schedule_wrap(function()
            vim.cmd('redrawstatus')
          end),
        },
      }

      local LSPActive = {
        condition = conditions.lsp_attached,
        update = { 'LspAttach', 'LspDetach' },

        -- You can keep it simple,
        -- provider = ' [LSP]',

        -- Or complicate things a bit and get the servers names
        provider = function()
          local names = {}
          for _, server in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
            table.insert(names, server.name)
          end
          return ' [' .. table.concat(names, ' ') .. ']'
        end,
        hl = { fg = theme_colors.green, bold = true },
      }

      local Ruler = {
        -- :help 'statusline'
        -- ------------------
        -- %-2 : make item takes at least 2 cells and be left justified
        -- %l  : current line number
        -- %L  : number of lines in the buffer
        -- %c  : column number
        -- %V  : virtual column number as -{num}.  Not displayed if equal to '%c'.
        provider = '%4(%l%):%-3(%v%)',
        hl = { bold = true }
      }

      local ScrollBar = {
        static = {
          sbar = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' }
          -- Another variant, because the more choice the better.
        },
        provider = function(self)
          local curr_line = vim.api.nvim_win_get_cursor(0)[1]
          local lines = vim.api.nvim_buf_line_count(0)
          local i = math.floor((curr_line - 1) / lines * #self.sbar) + 1
          return string.rep(self.sbar[i], 2)
        end,
        hl = function()
          local mode = vim.fn.mode(1):sub(1, 1) -- get only the first mode character
          return { fg = ViMode.static.mode_bgs[mode], bg = 'bright_bg' }
        end
      }

      local Diagnostics = {

        condition = conditions.has_diagnostics,

        static = {
          error_icon = ' ',
          warn_icon = ' ',
          info_icon = ' ',
          hint_icon = ' ',
        },

        init = function(self)
          self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
          self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
          self.hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
          self.info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
        end,

        update = { 'DiagnosticChanged', 'BufEnter' },

        {
          provider = function(self)
            -- 0 is just another output, we can decide to print it or not!
            return self.errors > 0 and (self.error_icon .. self.errors .. ' ')
          end,
          hl = { fg = 'diag_error' },
        },
        {
          provider = function(self)
            return self.warnings > 0 and (self.warn_icon .. self.warnings .. ' ')
          end,
          hl = { fg = 'diag_warn' },
        },
        {
          provider = function(self)
            return self.info > 0 and (self.info_icon .. self.info .. ' ')
          end,
          hl = { fg = 'diag_info' },
        },
        {
          provider = function(self)
            return self.hints > 0 and (self.hint_icon .. self.hints)
          end,
          hl = { fg = 'diag_hint' },
        },
      }

      local FileIcon = {
        init = function(self)
          local filename = self.filename
          local extension = vim.fn.fnamemodify(filename, ':e')
          self.icon, self.icon_color = require('nvim-web-devicons').get_icon_color(filename, extension,
            { default = true })
        end,
        provider = function(self)
          return self.icon and (self.icon .. ' ')
        end,
        hl = function(self)
          return { fg = self.icon_color }
        end
      }

      local FileName = {
        provider = function(self)
          -- first, trim the pattern relative to the current directory. For other
          -- options, see :h filename-modifers
          local filename = vim.fn.fnamemodify(self.filename, ':.')
          if filename == '' then return '[No Name]' end
          -- now, if the filename would occupy more than 1/4th of the available
          -- space, we trim the file path to its initials
          -- See Flexible Components section below for dynamic truncation
          if not conditions.width_percent_below(#filename, 0.25) then
            filename = vim.fn.pathshorten(filename)
          end
          return filename
        end,
        hl = { fg = utils.get_highlight('Directory').fg },
      }

      local FileFlags = {
        {
          condition = function()
            return vim.bo.modified
          end,
          provider = '[+]',
          hl = { fg = theme_colors.green },
        },
        {
          condition = function()
            return not vim.bo.modifiable or vim.bo.readonly
          end,
          provider = ' ',
          hl = { fg = 'red' },
        },
      }

      -- Now, let's say that we want the filename color to change if the buffer is
      -- modified. Of course, we could do that directly using the FileName.hl field,
      -- but we'll see how easy it is to alter existing components using a 'modifier'
      -- component

      local FileNameModifer = {
        hl = function()
          if vim.bo.modified then
            -- use `force` because we need to override the child's hl foreground
            return { fg = 'cyan', bold = true, force = true }
          end
        end,
      }

      local FileNameBlock = {
        -- let's first set up some attributes needed by this component and its children
        init = function(self)
          self.filename = vim.api.nvim_buf_get_name(0)
        end,
      }

      -- let's add the children to our FileNameBlock component
      FileNameBlock = utils.insert(FileNameBlock,
        FileIcon,
        utils.insert(FileNameModifer, FileName), -- a new table where FileName is a child of FileNameModifier
        FileFlags,
        { provider = '%<' }                      -- this means that the statusline is cut here when there's not enough space
      )

      local FileType = {
        provider = function()
          return string.upper(vim.bo.filetype)
        end,
        hl = { fg = utils.get_highlight('Type').fg, bold = true },
      }

      local Git = {
        condition = conditions.is_git_repo,

        init = function(self)
          self.status_dict = vim.b.gitsigns_status_dict
          self.has_changes = self.status_dict.added ~= 0 or self.status_dict.removed ~= 0 or
              self.status_dict.changed ~= 0
        end,

        hl = { fg = 'orange' },


        { -- git branch name
          provider = function(self)
            return ' ' .. self.status_dict.head
          end,
          hl = { bold = true }
        },
        -- You could handle delimiters, icons and counts similar to Diagnostics
        {
          provider = function(self)
            local count = self.status_dict.added or 0
            return count > 0 and ('  ' .. count)
          end,
          hl = { fg = 'git_add' },
        },
        {
          provider = function(self)
            local count = self.status_dict.removed or 0
            return count > 0 and ('  ' .. count)
          end,
          hl = { fg = 'git_del' },
        },
        {
          provider = function(self)
            local count = self.status_dict.changed or 0
            return count > 0 and ('  ' .. count)
          end,
          hl = { fg = 'git_change' },
        },
      }

      local HelpFileName = {
        condition = function()
          return vim.bo.filetype == 'help'
        end,
        provider = function()
          local filename = vim.api.nvim_buf_get_name(0)
          return vim.fn.fnamemodify(filename, ':t')
        end,
        hl = { fg = colors.blue },
      }

      local TerminalName = {
        -- we could add a condition to check that buftype == 'terminal'
        -- or we could do that later (see #conditional-statuslines below)
        provider = function()
          local tname, _ = vim.api.nvim_buf_get_name(0):gsub('.*:', '')
          local idx = tname:match(';#toggleterm#(.*)')
          if idx ~= nil then
            tname = tname:gsub(';#.*', '')
            return string.format(' %s [%d]', tname, idx)
          else
            return ' ' .. tname
          end
        end,
        hl = { fg = colors.blue, bold = true },
      }

      local Align = { provider = '%=' }
      local Space = { provider = ' ' }

      local SpecialStatusline = {
        condition = function()
          return conditions.buffer_matches({
            buftype = { 'nofile', 'prompt', 'help', 'quickfix' },
            filetype = { '^git.*', 'fugitive' },
          })
        end,

        FileType,
        Space,
        HelpFileName,
        Align
      }

      local TerminalStatusline = {
        condition = function()
          return conditions.buffer_matches({ buftype = { 'terminal' } })
        end,

        hl = { bg = theme_colors.surface0 },

        -- Quickly add a condition to the ViMode to only show it when buffer is active!
        { condition = conditions.is_active, ViMode, Space },
        TerminalName,
        Align,
      }

      local DefaultStatusline = {
        ViMode,
        Space,
        FileNameBlock,
        Space,
        Git,
        Align,
        Diagnostics,
        Space,
        Ruler,
        Space,
        LSPActive,
        Space,
        ScrollBar
      }

      local InactiveViMode = {
        provider = function()
          return '%2(%)'
        end,
        hl = { bg = 'bright_bg' }
      }

      local InactiveStatusline = {
        condition = conditions.is_not_active,
        InactiveViMode,
        Space,
        {
          hl = { fg = 'bright_bg', force = true },
          FileNameBlock,
          Space,
          Git,
          Align,
          Diagnostics,
          Space,
          Ruler,
          Space,
          LSPActive,
          Space,
          ScrollBar
        }
      }

      local StatusLines = {
        hl = function()
          if conditions.is_active() then
            return 'StatusLine'
          else
            return 'StatusLineNC'
          end
        end,

        -- the first statusline with no condition, or which condition returns true is used.
        -- think of it as a switch case with breaks to stop fallthrough.
        fallthrough = false,

        SpecialStatusline,
        TerminalStatusline,
        InactiveStatusline,
        DefaultStatusline,
      }

      require('heirline').setup({ statusline = StatusLines })
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
