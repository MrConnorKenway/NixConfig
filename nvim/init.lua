-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    lazyrepo,
    lazypath,
  }
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.o.sessionoptions = 'buffers,curdir,folds,tabpages,winsize'
vim.o.equalalways = false
vim.o.numberwidth = 2
vim.o.statuscolumn = '%l%s'
vim.o.listchars = 'tab:⇥ ,lead:·,trail:•,multispace:·'

vim.opt.ignorecase = true
vim.opt.termguicolors = true
vim.opt.smartcase = true
vim.opt.showmode = false

vim.lsp.set_log_level('off')

vim.g.mapleader = ' '
vim.g.no_python_maps = true

if os.getenv('SSH_TTY') ~= nil then
  local function paste()
    return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') }
  end
  local osc52 = require('vim.ui.clipboard.osc52')
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = osc52.copy('+'),
      ['*'] = osc52.copy('*'),
    },
    paste = {
      ['+'] = paste,
      ['*'] = paste,
    },
  }
end

local function is_last_window()
  local wins = vim.api.nvim_list_wins()
  local count = 0

  for _, win in ipairs(wins) do
    -- According to ':h nvim_win_get_config()', `relative` is empty for
    -- normal windows
    if vim.api.nvim_win_get_config(win).relative == '' then
      count = count + 1
    end
  end

  return count == 1
end

local function confirm_to_exit()
  if require('shrun').nr_tasks_by_status()['RUNNING'] > 0 then
    local choice = vim.fn.confirm(
      'Are you asure to exit? There are running tasks.',
      '&Yes\n&No',
      2,
      'Question'
    )
    return choice == 1
  end

  return true
end

vim.keymap.set('n', 'q', function()
  if vim.fn.tabpagenr('$') == 1 and is_last_window() then
    if not confirm_to_exit() then
      return
    end
  end

  vim.cmd('q')
end, { desc = 'Close window' })

vim.keymap.set('n', '<leader>q', function()
  if confirm_to_exit() then
    vim.cmd('qa')
  end
end, { desc = 'Quit workspace without save' })

vim.keymap.set('n', '<leader>x', function()
  if confirm_to_exit() then
    vim.cmd('xa')
  end
end, { desc = 'Save and quit workspace' })

vim.keymap.set('n', 'cq', '<cmd>cclose<cr>', { desc = 'Close quickfix' })
vim.keymap.set(
  'n',
  '<leader>w',
  '<cmd>wa<cr>',
  { desc = 'Save workspace without quit' }
)
vim.keymap.set(
  { 'i', 'n' },
  '<D-s>',
  '<cmd>wa<cr>',
  { desc = 'Save workspace without quit' }
)
vim.keymap.set('v', '<leader>c', '"+y', { desc = 'OSC52 copy' })
vim.keymap.set('v', '<D-c>', '"+y', { desc = 'OSC52 copy' })
vim.keymap.set(
  't',
  '<C-;>',
  vim.api.nvim_replace_termcodes('<C-\\><C-N>', true, true, true),
  { silent = true, desc = 'Exit terminal mode' }
)
vim.keymap.set({ 'n', 'i' }, '<D-z>', '<cmd>normal! u<cr>', { desc = 'Undo' })
vim.keymap.set(
  { 'n', 'i', 't' },
  '<C-tab>',
  '<cmd>tabnext<cr>',
  { desc = 'Go to next tab page' }
)
vim.keymap.set(
  { 'n', 'i', 't' },
  '<C-S-tab>',
  '<cmd>tabprevious<cr>',
  { desc = 'Go to previous tab page' }
)
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'gitcommit',
  callback = function()
    vim.keymap.set({ 'n', 'i' }, '<S-cr>', function()
      vim.cmd('x')
    end)
  end,
})

-- copy from https://github.com/neovim/neovim/pull/28176/files#diff-49225a49c226c2f1b36f966d0178c556e204cdc0b660c80db9e4568e03f6ef99R126
-- WARN: may change as neovim updates
vim.keymap.set('n', '<C-/>', function()
  return require('vim._comment').operator() .. '_'
end, { expr = true, desc = 'Comment current line' })
vim.keymap.set('n', '<D-/>', function()
  return require('vim._comment').operator() .. '_'
end, { expr = true, desc = 'Comment current line' })
vim.keymap.set('v', '<C-/>', function()
  return require('vim._comment').operator()
end, { expr = true, desc = 'Comment current block' })
vim.keymap.set('v', '<D-/>', function()
  return require('vim._comment').operator()
end, { expr = true, desc = 'Comment current block' })

-- readline-style keybindings
vim.keymap.set({ 'c', 'i' }, '<C-b>', '<Left>')
vim.keymap.set({ 'c', 'i' }, '<C-f>', '<Right>')
vim.keymap.set('i', '<C-p>', '<Up>')
vim.keymap.set('i', '<C-n>', '<Down>')
vim.keymap.set({ 'c', 'i' }, '<C-a>', '<Home>')
vim.keymap.set('i', '<C-e>', '<End>')
vim.keymap.set({ 'c', 'i' }, '<M-b>', '<S-Left>')
vim.keymap.set({ 'c', 'i' }, '<M-f>', '<S-Right>')

vim.keymap.del('n', 'grn')
vim.keymap.del('n', 'grr')
vim.keymap.del({ 'n', 'x' }, 'gra')
vim.keymap.del('n', 'gri')

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
          vim.cmd('normal! g`"')
        end
      end,
    })
  end,
})

local function set_wo_for_special_buf(filetype)
  if filetype == 'floggraph' then
    vim.wo.cursorline = true
  else
    vim.wo.cursorline = false
  end
  vim.wo.number = false
  vim.wo.list = false
  vim.wo.signcolumn = 'no'
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'floggraph', 'fugitive', 'git' },
  callback = function(args)
    set_wo_for_special_buf(args.match)
  end,
})

vim.api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter' }, {
  callback = function()
    if vim.bo.buftype:len() > 0 then
      set_wo_for_special_buf(vim.bo.filetype)
      return
    end

    vim.wo.number = true
    vim.wo.list = true
    vim.wo.cursorline = true
    vim.wo.signcolumn = 'yes:1'
  end,
})

vim.api.nvim_create_autocmd('WinLeave', {
  callback = function()
    vim.wo.cursorline = false
  end,
})

---@type table<number, {token:lsp.ProgressToken, msg:string, done:boolean}[]>
local progress = vim.defaulttable()
vim.api.nvim_create_autocmd('LspProgress', {
  ---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local value = ev.data.params.value --[[@as {percentage?: number, title?: string, message?: string, kind: 'begin' | 'report' | 'end'}]]
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

    local spinner =
      { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
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

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    vim.keymap.set('n', 'K', function()
      vim.lsp.buf.hover { border = 'rounded' }
    end, { desc = 'LSP hover', buffer = event.buf })

    vim.keymap.set('n', '<leader>i', function()
      vim.lsp.inlay_hint.enable(
        not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }
      )
    end, { desc = 'Toggle LSP inlay hint', buffer = event.buf })

    vim.keymap.set(
      'n',
      '<F2>',
      vim.lsp.buf.rename,
      { desc = 'LSP Rename', buffer = event.buf }
    )

    vim.keymap.set(
      'n',
      'g.',
      vim.lsp.buf.code_action,
      { desc = 'LSP code actions', buffer = event.buf }
    )
  end,
})

vim.diagnostic.config {
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '',
      [vim.diagnostic.severity.WARN] = '',
      [vim.diagnostic.severity.INFO] = '',
      [vim.diagnostic.severity.HINT] = '',
    },
    numhl = {
      [vim.diagnostic.severity.ERROR] = 'DiagnosticError',
      [vim.diagnostic.severity.WARN] = 'DiagnosticWarn',
      [vim.diagnostic.severity.INFO] = 'DiagnosticInfo',
      [vim.diagnostic.severity.HINT] = 'DiagnosticHint',
    },
  },
}

vim.lsp.enable('lua_ls')
vim.lsp.enable('clangd')
vim.lsp.enable('nixd')
vim.lsp.enable('basedpyright')

require('lazy').setup {
  spec = {
    { import = 'plugins.ui' },
    { import = 'plugins.git' },
    { import = 'plugins.lsp' },
    { import = 'plugins.edit' },
    { import = 'plugins.utils' },
  },
  ui = {
    border = 'rounded',
  },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip',
        'tarPlugin',
        'tohtml',
        'zipPlugin',
        'tutor',
        'netrwPlugin',
      },
    },
  },
}

vim.keymap.set('n', '<leader>l', function()
  require('lazy.view').show('home')
end, { desc = 'Display lazy' })

require('shrun').setup()

vim.api.nvim_create_autocmd('FileType', {
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

vim.api.nvim_create_user_command('LspRestart', function()
  local clients = vim.lsp.get_clients { bufnr = 0 }
  if not clients or next(clients) == nil then
    return
  end

  local clients_to_restart = {}

  for _, client in ipairs(clients) do
    client:stop()
    clients_to_restart[client.name] =
      { client, vim.tbl_keys(client.attached_buffers) }
  end

  local timer = assert(vim.uv.new_timer())
  local retry_count = 0
  timer:start(
    500,
    100,
    vim.schedule_wrap(function()
      if retry_count == 3 then
        pcall(timer.close, timer)
      end

      retry_count = retry_count + 1

      for client_name, tuple in pairs(clients_to_restart) do
        ---@type vim.lsp.Client
        local client, attached_buffers = unpack(tuple)
        local config = vim.tbl_deep_extend(
          'force',
          vim.lsp.config[client_name],
          client.config
        )
        if client:is_stopped() then
          for _, buf in ipairs(attached_buffers) do
            vim.lsp.start(config, { bufnr = buf })
          end
          clients_to_restart[client_name] = nil
        end
      end

      if next(clients_to_restart) == nil and not timer:is_closing() then
        timer:close()
      end
    end)
  )
end, { desc = 'Restart the LSP server attached to current buffer' })
