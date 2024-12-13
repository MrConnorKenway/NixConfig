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

vim.o.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize'

vim.opt.ignorecase = true
vim.opt.termguicolors = true
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

vim.keymap.set('n', 'q', '<cmd>q<cr>', { desc = 'Close window' })
vim.keymap.set('n', 'cq', '<cmd>cclose<cr>', { desc = 'Close quickfix' })
vim.keymap.set('n', '[q', '<cmd>cprevious<cr>', { desc = 'Previous quickfix' })
vim.keymap.set('n', ']q', '<cmd>cnext<cr>', { desc = 'Next quickfix' })
vim.keymap.set('n', '<leader>w', '<cmd>wa<cr>', { desc = 'Save workspace without quit' })
vim.keymap.set({ 'i', 'n' }, '<D-s>', '<cmd>wa<cr>', { desc = 'Save workspace without quit' })
vim.keymap.set('n', '<leader>x', '<cmd>xa<cr>', { desc = 'Save and quit workspace' })
vim.keymap.set('n', '<leader>q', '<cmd>qa<cr>', { desc = 'Quit workspace without save' })
vim.keymap.set('v', '<leader>c', '"+y', { desc = 'OSC52 copy' })
vim.keymap.set('t', '<C-;>', vim.api.nvim_replace_termcodes('<C-\\><C-N>', true, true, true),
  { silent = true, desc = 'Exit terminal mode' })

vim.cmd [[nnoremap <silent>  * :let @/='\C\<' . expand('<cword>') . '\>'<CR>:let v:searchforward=1<CR>n]]
vim.cmd [[nnoremap <silent>  # :let @/='\C\<' . expand('<cword>') . '\>'<CR>:let v:searchforward=0<CR>n]]
vim.cmd [[nnoremap <silent> g* :let @/='\C'   . expand('<cword>')       <CR>:let v:searchforward=1<CR>n]]
vim.cmd [[nnoremap <silent> g# :let @/='\C'   . expand('<cword>')       <CR>:let v:searchforward=0<CR>n]]

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


-- readline-style keybindings
vim.keymap.set('i', '<C-b>', '<Left>', { silent = true })
vim.keymap.set('i', '<C-f>', '<Right>', { silent = true })
vim.keymap.set('i', '<C-p>', '<Up>', { silent = true })
vim.keymap.set('i', '<C-n>', '<Down>', { silent = true })
vim.keymap.set('i', '<C-a>', '<Home>', { silent = true })
vim.keymap.set('i', '<C-e>', '<End>', { silent = true })


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

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'floggraph',
  callback = function()
    vim.wo[0][0].number = false
    vim.wo[0][0].list = false
  end
})

autocmd({ 'VimEnter', 'WinEnter', 'BufWinEnter' }, function()
  if vim.bo.buftype:len() > 0 then
    -- current buf is special buf
    return
  end

  if not vim.wo[0][0].number then
    vim.wo[0][0].number = true
  end

  if vim.wo[0][0].number then
    vim.wo[0][0].list = true
    vim.wo[0][0].listchars = 'tab:⇥ ,lead:·,trail:•,multispace:·'
    vim.wo[0][0].cursorline = true
    vim.wo[0][0].signcolumn = 'yes'
  end
end)

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
  callback = function()
    if vim.g.termmode == 't' then
      vim.cmd('startinsert')
    end
  end,
  pattern = { 'term://*' },
})

vim.api.nvim_create_autocmd({ 'WinLeave' }, {
  callback = function()
    vim.g.termmode = vim.fn.mode(1)
  end,
  pattern = { 'term://*' },
})

autocmd('TermOpen', function()
  vim.wo[0][0].number = false
  vim.wo[0][0].list = false
  vim.wo[0][0].cursorline = false
  vim.wo[0][0].signcolumn = 'no'
end)

autocmd({ 'WinLeave' }, function()
  vim.wo[0][0].cursorline = false
end)

---@type table<number, {token:lsp.ProgressToken, msg:string, done:boolean}[]>
local progress = vim.defaulttable()
vim.api.nvim_create_autocmd('LspProgress', {
  ---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local value = ev.data.params
        .value --[[@as {percentage?: number, title?: string, message?: string, kind: 'begin' | 'report' | 'end'}]]
    if not client or type(value) ~= 'table' then
      return
    end
    local p = progress[client.id]

    for i = 1, #p + 1 do
      if i == #p + 1 or p[i].token == ev.data.params.token then
        p[i] = {
          token = ev.data.params.token,
          msg = ('[%3d%%] %s%s'):format(
            value.kind == 'end' and 100 or value.percentage or 100,
            value.title or '',
            value.message and (' **%s**'):format(value.message) or ''
          ),
          done = value.kind == 'end',
        }
        break
      end
    end

    local msg = {} ---@type string[]
    progress[client.id] = vim.tbl_filter(function(v)
      return table.insert(msg, v.msg) or not v.done
    end, p)

    local spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
    vim.notify(table.concat(msg, '\n'), 'info', {
      id = 'lsp_progress',
      title = client.name,
      opts = function(notif)
        notif.icon = #progress[client.id] == 0 and ' '
            or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
      end,
    })
  end,
})

require('lazy').setup({
  require('heirline.config'),
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = true
  },
  {
    'kylechui/nvim-surround',
    event = 'VeryLazy',
    config = function()
      require('nvim-surround').setup()
    end
  },
  {
    'b0o/incline.nvim',
    dependencies = { 'SmiteshP/nvim-navic', 'nvim-tree/nvim-web-devicons' },
    event = 'VeryLazy',
    config = function()
      local helpers = require 'incline.helpers'
      local navic = require 'nvim-navic'
      local devicons = require 'nvim-web-devicons'
      local type_hl = {
        File = 'Directory',
        Module = '@include',
        Namespace = '@namespace',
        Package = '@include',
        Class = '@structure',
        Method = '@method',
        Property = '@property',
        Field = '@field',
        Constructor = '@constructor',
        Enum = '@field',
        Interface = '@type',
        Function = '@function',
        Variable = '@variable',
        Constant = '@constant',
        String = '@string',
        Number = '@number',
        Boolean = '@boolean',
        Array = '@field',
        Object = '@type',
        Key = '@keyword',
        Null = '@comment',
        EnumMember = '@field',
        Struct = '@structure',
        Event = '@keyword',
        Operator = '@operator',
        TypeParameter = '@type',
      }

      require('incline').setup {
        window = {
          padding = 0,
          margin = { horizontal = 0, vertical = 1 },
        },
        hide = {
          cursorline = true,
          focused_win = false,
          only_win = false
        },
        render = function(props)
          local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ':t')
          if filename == '' then
            filename = '[No Name]'
          end

          local extension = vim.fn.fnamemodify(filename, ':e')
          local ft_icon, ft_color = devicons.get_icon_color(filename, extension, { default = true })
          local modified = vim.bo[props.buf].modified
          local res = {
            ft_icon and { ' ', ft_icon, ' ', guibg = ft_color, guifg = helpers.contrast_color(ft_color) } or '',
            ' ',
            { filename, gui = modified and 'bold,italic' or 'bold' },
            guibg = require('catppuccin.palettes').get_palette().surface0
          }
          if props.focused then
            local len = 0
            for i, item in ipairs(navic.get_data(props.buf) or {}) do
              len = len + #item.icon + #item.name
              if len / vim.api.nvim_win_get_width(0) > 0.45 and i > 1 then
                table.insert(res, { { '  ..' } })
                break
              end
              table.insert(res, {
                { '  ', group = 'NavicSeparator' },
                { item.icon, group = type_hl[item.type] },
                { item.name, group = type_hl[item.type] }
              })
            end
          end
          table.insert(res, ' ')
          return res
        end,
      }
    end
  },
  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on lua files
    config = function()
      require('lazydev').setup()
    end
  },
  {
    'folke/noice.nvim',
    dependencies = { 'MunifTanjim/nui.nvim' },
    config = function()
      require('noice').setup {
        lsp = {
          progress = { enabled = false },
          hover = { enabled = false },
          signature = { enabled = false }
        },
      }
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
      vim.keymap.set('n', ']c', function()
        if vim.api.nvim_buf_get_name(0):match('fugitive://') then
          vim.cmd('normal! ]c | zz')
        else
          gitsigns.nav_hunk('next')
        end
      end, { desc = 'Go to next git change' })
      vim.keymap.set('n', '[c', function()
        if vim.api.nvim_buf_get_name(0):match('fugitive://') then
          vim.cmd('normal! [c | zz')
        else
          gitsigns.nav_hunk('prev')
        end
      end, { desc = 'Go to previous git change' })
      vim.keymap.set('n', '<leader>u', gitsigns.reset_hunk, { desc = 'Git reset hunk' })
      vim.keymap.set('n', '<leader>b', gitsigns.blame_line, { desc = 'Git blame inline' })
      vim.keymap.set('n', 'ga', gitsigns.stage_hunk, { desc = 'Git stage hunk' })
    end
  },
  {
    'tpope/vim-fugitive',
    keys = {
      { 'gs',        '<cmd>G<cr>',            desc = 'Git status' },
      { 'gv',        '<cmd>vertical G<cr>',   desc = 'Git status vertical' },
      { 'gl',        '<cmd>G log --stat<cr>', desc = 'Git log' },
      { 'gu',        '<cmd>Git! push<cr>',    desc = 'Git push' },
      { '<leader>d', '<cmd>Gdiffsplit<cr>',   desc = 'Git diff' },
      { '<leader>g', ':G ',                   desc = 'Git cmdline' }
    },
    event = 'CmdlineEnter',
    init = function()
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'fugitive', 'git' },
        callback = function()
          vim.keymap.set('n', '<C-p>', function() vim.api.nvim_feedkeys('(', 't', true) end, { buffer = true })
          vim.keymap.set('n', '<C-n>', function() vim.api.nvim_feedkeys(')', 't', true) end, { buffer = true })
        end
      })
    end
  },
  {
    'tpope/vim-dispatch',
    keys = {
      { '`<Space>', ':Dispatch ',     desc = 'Dispatch command to run and return results in quickfix' },
      { "'<Space>", ':Start ',        desc = 'Start an eval process in a new focused window' },
      { '``',       '<cmd>Start<cr>', desc = 'Start a shell in a new focused window' },
    },
    init = function()
      vim.g.dispatch_no_maps = 1
    end
  },
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = { labels = 'asdfjkl;weionmcvgh' },
    keys = {
      {
        'S',
        function()
          require('flash').treesitter({ label = { rainbow = { enabled = true } } })
        end,
        desc = 'Flash Treesitter'
      },
      { 's', function() require('flash').jump() end, desc = 'Flash' },
    }
  },
  { 'akinsho/git-conflict.nvim', config = true },
  {
    'nvimdev/hlsearch.nvim',
    event = 'BufRead',
    config = function()
      require('hlsearch').setup()
    end
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
      {
        'gp',
        function() require('goto-preview').goto_preview_definition {} end,
        desc = 'Preview LSP definition in popup'
      },
      {
        'gr',
        function() require('goto-preview').goto_preview_references {} end,
        desc = 'Preview LSP references in popup'
      },
    },
    config = function()
      require('goto-preview').setup {
        border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
        zindex = 100
      }
    end
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

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, { callback = on_cursor_moved, buffer = 0 })
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

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, { callback = on_cursor_moved, buffer = 0 })
      end, { desc = 'Go to end of parent syntax tree node' })
    end
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin-colorscheme',
    priority = 1000,
    lazy = false,
    init = function()
      vim.cmd.colorscheme('catppuccin-mocha')
    end,
    config = function()
      require('catppuccin').setup {
        integrations = {
          blink_cmp = true
        }
      }
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
    'otavioschwanck/arrow.nvim',
    event = 'UIEnter',
    keys = {
      { '<C-S-n>', function() require('arrow.persist').next() end,     desc = 'Move to next arrow buffer' },
      { '<C-S-p>', function() require('arrow.persist').previous() end, desc = 'Move to previous arrow buffer' }
    },
    dependencies = {
      { 'nvim-tree/nvim-web-devicons' },
    },
    opts = {
      show_icons = true,
      leader_key = 'm',
      window = {
        border = 'rounded'
      }
    }
  },
  {
    'rbong/vim-flog',
    cmd = { 'Flog', 'Flogsplit', 'Floggit' },
    keys = {
      { '<S-M-l>', function() vim.cmd('vertical Flogsplit') end, desc = 'Display git graph' },
      { '<S-D-l>', function() vim.cmd('vertical Flogsplit') end, desc = 'Display git graph' }
    },
    dependencies = {
      'tpope/vim-fugitive',
    },
  },
  {
    'dgagn/diagflow.nvim',
    event = 'LspAttach',
    config = function()
      require('diagflow').setup({
        enable = true,
        max_width = 60,     -- The maximum width of the diagnostic messages
        max_height = 10,    -- the maximum height per diagnostics
        severity_colors = { -- The highlight groups to use for each diagnostic severity level
          error = 'DiagnosticFloatingError',
          warning = 'DiagnosticFloatingWarn',
          info = 'DiagnosticFloatingInfo',
          hint = 'DiagnosticFloatingHint',
        },
        format = function(diagnostic)
          return diagnostic.message
        end,
        gap_size = 1,
        scope = 'cursor',
        padding_top = 1,
        padding_right = 0,
        text_align = 'right',                                  -- 'left', 'right'
        placement = 'top',                                     -- 'top', 'inline'
        inline_padding_left = 0,                               -- the padding left when the placement is inline
        update_event = { 'DiagnosticChanged', 'BufReadPost' }, -- the event that updates the diagnostics cache
        toggle_event = { 'InsertEnter', 'InsertLeave' },       -- if InsertEnter, can toggle the diagnostics on inserts
        show_sign = false,
        render_event = { 'DiagnosticChanged', 'CursorMoved' },
        border_chars = {
          top_left = '╭',
          top_right = '╮',
          bottom_left = '╰',
          bottom_right = '╯',
          horizontal = '─',
          vertical = '│'
        },
        show_borders = true,
      })
    end
  },
  {
    'stevearc/dressing.nvim',
    event = 'VeryLazy'
  },
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    keys = {
      { '<leader>n', function() Snacks.notifier.show_history() end, desc = 'Notification History' },
      { '<leader>c', function() Snacks.bufdelete.delete() end,      desc = 'Close buffer' }
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
    },
    config = true
  },
  {
    'akinsho/toggleterm.nvim',
    keys = {
      {
        '<D-j>',
        mode = { 'n', 'i', 't' },
        function() require('toggleterm').toggle(nil, nil, nil, 'float', nil) end,
        desc = 'Toggle terminal at current window'
      },
      {
        '<C-`>',
        mode = { 'n', 'i', 't' },
        function() require('toggleterm').toggle(nil, nil, nil, 'float', nil) end,
        desc = 'Toggle terminal at current window'
      },
    },
    config = function()
      require('toggleterm').setup {
        size = 16,
        shade_terminals = true,
        float_opts = { border = 'rounded' }
      }
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
      { '<leader>o', function() require('fzf-lua').files() end,   desc = 'FzfLua find files' },
      {
        '<D-o>',
        mode = { 'n', 't', 'i' },
        function() require('fzf-lua').files() end,
        desc = 'FzfLua find files'
      },
      {
        '<leader>O',
        function() require('fzf-lua').files { cwd = vim.fn.expand('%:h') } end,
        desc = 'FzfLua find files in directory of current buffer'
      },
      { '<leader>p', function() require('fzf-lua').buffers() end, desc = 'FzfLua switch buffers' },
      {
        '<D-p>',
        mode = { 'n', 't', 'i' },
        function() require('fzf-lua').buffers() end,
        desc = 'FzfLua switch buffers'
      },
      {
        '<leader>fg',
        function()
          require('fzf-lua').live_grep_native()
        end,
        desc = 'FzfLua live grep'
      },
      {
        '<S-D-f>',
        mode = { 'n', 't', 'i' },
        function() require('fzf-lua').live_grep_native() end,
        desc = 'FzfLua live grep'
      },
      {
        '<S-M-f>',
        mode = { 'n', 't', 'i' },
        function() require('fzf-lua').live_grep_native() end,
        desc = 'FzfLua live grep'
      },
      {
        '<D-f>',
        mode = { 'n', 'i' },
        function() require('fzf-lua').lgrep_curbuf() end,
        desc = 'FzfLua regex search current buffer'
      },
      {
        '<M-f>',
        mode = { 'n', 'i' },
        function() require('fzf-lua').lgrep_curbuf() end,
        desc = 'FzfLua regex search current buffer'
      },
      {
        '<D-t>',
        mode = { 'n', 'i' },
        function() require('fzf-lua').lsp_live_workspace_symbols() end,
        desc = 'FzfLua find workspace symbols'
      },
      {
        '<leader>s',
        function() require('fzf-lua').lsp_live_workspace_symbols() end,
        desc = 'FzfLua find workspace symbols'
      }
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
            default = vim.fn.executable('bat') == 0 and 'builtin' or 'bat_native',
            delay = 100
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
            false,
            ['Ctrl-u'] = 'preview-half-page-up',
            ['Ctrl-d'] = 'preview-half-page-down',
            ['ctrl-a'] = 'beginning-of-line',
            ['ctrl-e'] = 'end-of-line',
            ['ctrl-f'] = 'half-page-down',
            ['ctrl-b'] = 'half-page-up',
            ['F9']     = 'toggle-preview'
          }
        }
      }
    end
  },
  {
    'abecodes/tabout.nvim',
    config = function()
      require('tabout').setup {
        tabkey = '<Tab>',             -- key to trigger tabout, set to an empty string to disable
        backwards_tabkey = '<S-Tab>', -- key to trigger backwards tabout, set to an empty string to disable
        act_as_tab = true,            -- shift content if tab out is not possible
        act_as_shift_tab = false,     -- reverse shift content if tab out is not possible (if your keyboard/terminal supports <S-Tab>)
        default_tab = '<C-t>',        -- shift default action (only at the beginning of a line, otherwise <TAB> is used)
        default_shift_tab = '<C-d>',  -- reverse shift default action,
        enable_backwards = true,      -- well ...
        completion = false,           -- if the tabkey is used in a completion pum
        tabouts = {
          { open = "'", close = "'" },
          { open = '"', close = '"' },
          { open = '`', close = '`' },
          { open = '(', close = ')' },
          { open = '[', close = ']' },
          { open = '<', close = '>' },
          { open = '{', close = '}' }
        },
        ignore_beginning = false, -- only tabout if at beginning of configured tabout chars
        exclude = {}              -- tabout will ignore these filetypes
      }
    end,
    dependencies = { -- These are optional
      'nvim-treesitter/nvim-treesitter',
      'hrsh7th/nvim-cmp'
    },
    opt = true, -- Set this to true if the plugin is optional
    event = 'InsertEnter'
  },
  {
    'saghen/blink.cmp',
    lazy = false, -- lazy loading handled internally

    -- use a release tag to download pre-built binaries
    version = 'v0.*',
    -- OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
    -- build = 'cargo build --release',
    -- If you use nix, you can build from source using latest nightly rust with:
    -- build = 'nix run .#build-plugin',

    opts = {
      -- 'default' for mappings similar to built-in completion
      -- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys to navigate)
      -- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
      -- see the "default configuration" section below for full documentation on how to define
      -- your own keymap.
      keymap = {
        ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
        ['<C-e>'] = { 'hide', 'fallback' },
        ['<CR>'] = { 'accept', 'fallback' },
        ['<Tab>'] = {
          function(cmp)
            if cmp.snippet_active() then
              return cmp.accept()
            else
              return cmp.select_and_accept()
            end
          end,
          'snippet_forward',
          'fallback'
        },
        ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
        ['<Up>'] = { 'select_prev', 'fallback' },
        ['<Down>'] = { 'select_next', 'fallback' },
        ['<C-p>'] = { 'select_prev', 'fallback' },
        ['<C-n>'] = { 'select_next', 'fallback' },
        ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
        ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
      },

      appearance = {
        -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono'
      },

      -- default list of enabled providers defined so that you can extend it
      -- elsewhere in your config, without redefining it, via `opts_extend`
      sources = {
        completion = {
          enabled_providers = { 'lsp', 'path' },
        },
      },

      completion = {
        accept = { auto_brackets = { enabled = true } },
        menu = {
          winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None',
          border = 'rounded'
        },
        documentation = {
          auto_show = true,
          window = {
            winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpDocCursorLine,Search:None',
            border = 'rounded'
          }
        }
      },

      signature = {
        enabled = true,
        window = {
          winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpDocCursorLine,Search:None',
          border = 'rounded'
        }
      }
    },
    -- allows extending the enabled_providers array elsewhere in your config
    -- without having to redefine it
    opts_extend = { 'sources.completion.enabled_providers' }
  },
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-cmdline'
    },
    event = { 'InsertEnter', 'CmdlineEnter' },
    config = function()
      local cmp = require('cmp')
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
          Variable = '󰆧 ',
          Constant = ' ',
          String = ' ',
          Number = ' ',
          Boolean = ' ',
          Array = '󰅪 ',
          Object = ' ',
          Key = '󰌋 ',
          Null = ' ',
          EnumMember = ' ',
          Struct = ' ',
          Event = ' ',
          Operator = '󰆕 ',
          TypeParameter = ' '
        },
        lsp = {
          auto_attach = true,
          preference = nil,
        },
        lazy_update_context = false,
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
          vim.keymap.set('n', 'g.', vim.lsp.buf.code_action, { desc = 'LSP code actions' })

          local signs = { Error = ' ', Warn = ' ', Hint = ' ', Info = ' ' }
          for type, icon in pairs(signs) do
            local hl = 'DiagnosticSign' .. type
            vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
          end
        end
      })

      local lspconfig = require('lspconfig')
      lspconfig.clangd.setup {
        cmd = { 'clangd', '--header-insertion=never' }
      }
      lspconfig.nixd.setup {}
      lspconfig.lua_ls.setup {}
      lspconfig.pylsp.setup {}
    end
  },
  {
    'stevearc/conform.nvim',
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
      {
        '<S-D-i>',
        mode = { 'n', 'i' },
        function()
          require('conform').format({ async = true })
        end,
        desc = 'LSP format current buffer'
      },
      {
        '<S-M-i>',
        mode = { 'n', 'i' },
        function()
          require('conform').format({ async = true })
        end,
        desc = 'LSP format current buffer'
      }
    },
    config = function()
      require('conform').setup({
        formatters_by_ft = {
          c = { 'clang-format' }
        },
        default_format_opts = {
          lsp_format = 'fallback'
        }
      })
    end
  },
  {
    'mrjones2014/smart-splits.nvim',
    keys = {
      {
        '<C-h>',
        mode = { 'n', 'i', 't' },
        function() require('smart-splits').move_cursor_left() end,
        desc = 'Move cursort left'
      },
      {
        '<C-j>',
        mode = { 'n', 'i', 't' },
        function() require('smart-splits').move_cursor_down() end,
        desc = 'Move cursort down'
      },
      {
        '<C-k>',
        mode = { 'n', 'i', 't' },
        function() require('smart-splits').move_cursor_up() end,
        desc = 'Move cursort up'
      },
      {
        '<C-l>',
        mode = { 'n', 'i', 't' },
        function() require('smart-splits').move_cursor_right() end,
        desc = 'Move cursort right'
      },
      {
        '<M-h>',
        mode = { 'n', 'i', 't' },
        function() require('smart-splits').resize_left() end,
        desc = 'Resize window left'
      },
      {
        '<M-j>',
        mode = { 'n', 'i', 't' },
        function() require('smart-splits').resize_down() end,
        desc = 'Resize window down'
      },
      {
        '<M-k>',
        mode = { 'n', 'i', 't' },
        function() require('smart-splits').resize_up() end,
        desc = 'Resize window up'
      },
      {
        '<M-l>',
        mode = { 'n', 'i', 't' },
        function() require('smart-splits').resize_right() end,
        desc = 'Resize window right'
      }
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
        '<leader>h',
        function() require('telescope.builtin').command_history() end,
        desc =
        'Telescope find command history'
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
