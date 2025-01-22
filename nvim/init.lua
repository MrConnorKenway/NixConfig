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
vim.keymap.set({ 'n', 'i' }, '<D-z>', '<cmd>normal! u<cr>', { desc = 'Undo' })

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


vim.api.nvim_create_autocmd('BufRead', {
  callback = function(opts)
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
  end
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'floggraph',
  callback = function()
    vim.wo[0][0].number = false
    vim.wo[0][0].list = false
  end
})

vim.api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter' }, {
  callback = function()
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
  end
})

vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    if vim.b.termmode == 't' then
      vim.cmd('startinsert')
    end
  end,
  pattern = { 'term://*' },
})

vim.api.nvim_create_autocmd('WinLeave', {
  callback = function()
    vim.b.termmode = vim.fn.mode(1)
  end,
  pattern = { 'term://*' },
})

vim.api.nvim_create_autocmd('TermOpen', {
  callback = function()
    vim.wo[0][0].number = false
    vim.wo[0][0].list = false
    vim.wo[0][0].cursorline = false
    vim.wo[0][0].signcolumn = 'no'
  end
})

vim.api.nvim_create_autocmd('WinLeave', {
  callback = function()
    vim.wo[0][0].cursorline = false
  end
})

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
    vim.notify(table.concat(msg, '\n'), vim.log.levels.INFO, {
      id = 'lsp_progress',
      title = client.name,
      opts = function(notif)
        notif.icon = #progress[client.id] == 0 and ' '
            or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
      end,
    })
  end,
})

require('lazy').setup {
  spec = {
    { import = 'plugins.ui' },
    { import = 'plugins.git' },
    { import = 'plugins.lsp' },
    { import = 'plugins.edit' },
    { import = 'plugins.utils' },
    { import = 'plugins.picker' }
  },
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
}

vim.keymap.set('n', '<leader>l', function() require('lazy.view').show('home') end, { desc = 'Display lazy' })
