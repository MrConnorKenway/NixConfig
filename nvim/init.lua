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
  { import = 'plugins.ui' },
  { import = 'plugins.lsp' },
  { import = 'plugins.edit' },
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
      { 'gs',        '<cmd>G<cr>',               desc = 'Git status' },
      { 'gv',        '<cmd>vertical G<cr>',      desc = 'Git status vertical' },
      { 'gl',        '<cmd>G log --stat<cr>',    desc = 'Git log' },
      { 'gu',        '<cmd>Git! push<cr>',       desc = 'Git push' },
      { '<leader>d', '<cmd>Gdiffsplit<cr>',      desc = 'Git diff' },
      { '<leader>D', '<cmd>Gvdiffsplit @:%<cr>', desc = 'Git diff with staged' },
      { '<leader>g', ':G ',                      desc = 'Git cmdline' }
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
  { 'akinsho/git-conflict.nvim', config = true },
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
    init = function()
      vim.g.flog_enable_extended_chars = true
    end,
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
    opts = {
      size = 16,
      shade_terminals = true,
      float_opts = { border = 'rounded' }
    }
  },
  {
    'prichrd/netrw.nvim',
    ft = 'netrw', -- only load on netrw files
    opts = {}
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
        '<leader>h',
        function() require('fzf-lua').command_history() end,
        desc =
        'FzfLua find command history'
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
      },
      {
        'gh',
        function()
          local M = {}

          M.toggle_regex = function(_, opts)
            opts.__ACT_TO {
              resume = true,
            }
          end

          local fzf_lua = require('fzf-lua')
          local common_opts = {
            winopts = { title = ' Git Hunks ', title_pos = 'center' },
            actions = fzf_lua.defaults.actions.files,
            file_icons = true,
            color_icons = true,
            previewer = 'bat_native',
            field_index_expr = '{1}',
            line_field_index = '{2}',
            multiprocess = true,
            fzf_opts = {
              ["--multi"] = true
            }
          }
          common_opts.actions['ctrl-g'] = { fn = M.toggle_regex, noclose = true }

          local fn_transform = function(x)
            return fzf_lua.make_entry.file(x, common_opts)
          end

          local check_pattern = function(pattern, line)
            if not pattern then
              return true
            end

            local ok, ret = pcall(string.match, line, pattern)
            if ok and ret then
              return true
            end

            return false
          end

          -- diffn parses git diff and produces line number for each hunk
          local diffn = function(fzf_cb, live_query)
            local diff_text = vim.fn.system('git diff')
            local file_name = nil
            local line_number = nil
            local counter = 0

            for line in diff_text:gmatch('([^\n]+)') do
              if counter < 3 then
                counter = counter + 1
                goto continue
              end

              if counter == 3 then
                -- +++ b/
                file_name = line:match('^%+%+%+ b/(.*)')
                counter = counter + 1
                goto continue
              end

              local char = line:sub(1, 1)

              if char == '-' then
                if check_pattern(live_query, line) then
                  fzf_cb(fn_transform(file_name) .. ':' .. line_number .. ':' .. ' \27[31m' .. line .. '\27[m')
                end
                goto continue
              end

              if char == '+' then
                if check_pattern(live_query, line) then
                  fzf_cb(fn_transform(file_name) .. ':' .. line_number .. ':' .. ' \27[32m' .. line .. '\27[m')
                end
                line_number = line_number + 1
                goto continue
              end

              if char == ' ' then
                line_number = line_number + 1
                goto continue
              end

              local new_line_number = line:match('^@@ %-%d+,%d+ %+(%d+),%d+ @@')
              if new_line_number then
                line_number = new_line_number
                goto continue
              end

              counter = 1
              ::continue::
            end

            fzf_cb()
          end

          M.fuzzy_hunks = function(opts)
            opts = opts or {}
            opts = vim.tbl_deep_extend('keep', opts, common_opts)
            opts.__ACT_TO = M.lgrep_hunks
            opts.prompt = 'fuzzy> '
            opts = require('fzf-lua.config').normalize_opts(opts, {}, "hunk")

            fzf_lua.fzf_exec(function(fzf_cb)
              diffn(fzf_cb)
            end, opts)
          end

          M.lgrep_hunks = function(opts)
            opts = opts or {}

            opts = vim.tbl_deep_extend('keep', opts, common_opts)
            opts.__ACT_TO = M.fuzzy_hunks
            opts.prompt = 'lgrep> '
            opts.exec_empty_query = true
            opts = require('fzf-lua.config').normalize_opts(opts, {}, "hunk")

            fzf_lua.fzf_live(
              function(query)
                return function(fzf_cb)
                  diffn(fzf_cb, query)
                end
              end,

              opts
            )
          end

          M.fuzzy_hunks()
        end
      }
    },
    dependencies = { 'nvim-tree/nvim-web-devicons', 'junegunn/fzf' },
    opts = {
      'default-title',
      files = {
        git_icons = false
      },
      winopts = {
        treesitter = {
          enabled = true,
          fzf_colors = false
        },
        backdrop = 100,
        height = 0.85,
        width = 0.85,
        row = 0.40,
        preview = {
          default = vim.fn.executable('bat') == 0 and 'builtin' or 'bat_native',
          horizontal = 'right:52%',
          delay = 100
        }
      },
      manpages = { previewer = 'man_native' },
      previewers = {
        man_native = {
          cmd = 'bash -l -c "man %s | col -bx" | ' ..
              (vim.fn.executable('bat') == 0 and 'cat' or 'bat --color=always -p -l man')
        }
      },
      grep = {
        rg_opts = '--column --line-number --no-heading --no-ignore --color=always --smart-case --max-columns=4096 -e'
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
    opts = {
      default_amount = 3
    }
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
        'gzip', 'tarPlugin', 'tohtml', 'zipPlugin', 'tutor'
      }
    }
  }
})

vim.keymap.set('n', '<leader>l', function() require('lazy.view').show('home') end, { desc = 'Display lazy' })
