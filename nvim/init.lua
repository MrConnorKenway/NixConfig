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

-- Only do the following when the TUI is attached
for _, ui in ipairs(vim.api.nvim_list_uis()) do
  if ui.chan == 1 and ui.stdout_tty then
    --- Enable the autocmd created by vim._defaults if background is set
    if vim.api.nvim_get_option_info2('background', {}).was_set then
      --- Parse a string of hex characters as a color.
      ---
      --- The string can contain 1 to 4 hex characters. The returned value is
      --- between 0.0 and 1.0 (inclusive) representing the intensity of the color.
      ---
      --- For instance, if only a single hex char "a" is used, then this function
      --- returns 0.625 (10 / 16), while a value of "aa" would return 0.664 (170 /
      --- 256).
      ---
      --- @param c string Color as a string of hex chars
      --- @return number? Intensity of the color
      local function parsecolor(c)
        if #c == 0 or #c > 4 then
          return nil
        end

        local val = tonumber(c, 16)
        if not val then
          return nil
        end

        local max = tonumber(string.rep('f', #c), 16)
        return val / max
      end

      --- Parse an OSC 11 response
      ---
      --- Either of the two formats below are accepted:
      ---
      ---   OSC 11 ; rgb:<red>/<green>/<blue>
      ---
      --- or
      ---
      ---   OSC 11 ; rgba:<red>/<green>/<blue>/<alpha>
      ---
      --- where
      ---
      ---   <red>, <green>, <blue>, <alpha> := h | hh | hhh | hhhh
      ---
      --- The alpha component is ignored, if present.
      ---
      --- @param resp string OSC 11 response
      --- @return string? Red component
      --- @return string? Green component
      --- @return string? Blue component
      local function parseosc11(resp)
        local r, g, b
        r, g, b = resp:match('^\027%]11;rgb:(%x+)/(%x+)/(%x+)$')
        if not r and not g and not b then
          local a
          r, g, b, a = resp:match('^\027%]11;rgba:(%x+)/(%x+)/(%x+)/(%x+)$')
          if not a or #a > 4 then
            return nil, nil, nil
          end
        end

        if r and g and b and #r <= 4 and #g <= 4 and #b <= 4 then
          return r, g, b
        end

        return nil, nil, nil
      end

      -- This autocommand updates the value of 'background' anytime we receive
      -- an OSC 11 response from the terminal emulator. If the user has set
      -- 'background' explicitly then we will delete this autocommand,
      -- effectively disabling automatic background setting.
      vim.api.nvim_create_autocmd('TermResponse', {
        nested = true,
        desc = "Update the value of 'background' automatically based on the terminal emulator's background color",
        callback = function(args)
          local resp = args.data.sequence ---@type string
          local r, g, b = parseosc11(resp)
          if r and g and b then
            local rr = parsecolor(r)
            local gg = parsecolor(g)
            local bb = parsecolor(b)

            if rr and gg and bb then
              local luminance = (0.299 * rr) + (0.587 * gg) + (0.114 * bb)
              local bg = luminance < 0.5 and 'dark' or 'light'
              vim.o.bg = bg
            end
          end
        end,
      })

      io.stdout:write('\027]11;?\007')
    end
    break
  end
end

local function is_current_window_last()
  local current_win = vim.api.nvim_get_current_win()
  local wins = vim.api.nvim_list_wins()
  local curr_is_normal = false
  local count = 0

  for _, win in ipairs(wins) do
    -- According to ':h nvim_win_get_config()', `relative` is empty for
    -- normal windows
    if vim.api.nvim_win_get_config(win).relative == '' then
      if win == current_win then
        curr_is_normal = true
      end
      count = count + 1
    end
  end

  --- If current window is not the only normal window (e.g., current window is
  --- floating window), then it is safe to close current window.
  return count == 1 and curr_is_normal and vim.fn.tabpagenr('$') == 1
end

local function confirm_to_exit()
  local shrun_shell = require('shrun').get_shell_job()
  local jobs = vim.tbl_filter(function(chan)
    return chan.stream == 'job' and chan.id ~= shrun_shell and chan.pty ~= ''
  end, vim.api.nvim_list_chans())

  if #jobs > 0 then
    local choice = vim.fn.confirm(
      'Are you asure to exit? There are running jobs.',
      '&Yes\n&No',
      2,
      'Question'
    )
    if choice == 1 then
      for _, job in ipairs(jobs) do
        vim.fn.jobstop(job.id)
      end
    else
      return false
    end
  end

  if shrun_shell then
    vim.fn.jobstop(shrun_shell)
  end
  return true
end

vim.keymap.set('n', 'q', function()
  if is_current_window_last() and not confirm_to_exit() then
    return
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
  pattern = { 'gitcommit', 'gitrebase' },
  callback = function()
    vim.keymap.set({ 'n', 'i' }, '<S-cr>', function()
      vim.cmd('x')
    end, { buffer = true })
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

local old_mouse_setting
local function save_mouse()
  if old_mouse_setting == nil then
    old_mouse_setting = vim.o.mouse
  end
  vim.o.mouse = ''
end

local function restore_mouse()
  if old_mouse_setting ~= nil then
    vim.o.mouse = old_mouse_setting
    old_mouse_setting = nil
  end
end

vim.cmd([[
map <RightMouse> <nop>
map <2-RightMouse> <nop>
map <3-RightMouse> <nop>
map <4-RightMouse> <nop>
]])

vim.api.nvim_create_autocmd('FocusLost', {
  desc = 'Save mouse setting and disable mouse on focus lost',
  callback = save_mouse,
})

vim.api.nvim_create_autocmd('FocusGained', {
  desc = 'Restore mouse setting on focus gained',
  callback = function()
    if vim.bo.buftype ~= 'terminal' then
      vim.defer_fn(restore_mouse, 10)
    end
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

vim.api.nvim_create_autocmd('TermEnter', {
  callback = function()
    save_mouse()
  end,
})

vim.api.nvim_create_autocmd('TermLeave', {
  callback = function()
    restore_mouse()
  end,
})

--- Record of id of window that is normal, focusable and contains regular
--- buffer, i.e., buffer with empty `buftype`. Note that a window that
--- contains non-empty `buftype` might also be recorded if such window is
--- created when the special buffer's type has not been set yet, e.g.,
--- some plugin may create a window by splitting current regular window,
--- and set the buffer to special buffer later.
vim.g.normal_winid_rec = nil

vim.api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter' }, {
  callback = function(args)
    if vim.bo.buftype:len() > 0 then
      set_wo_for_special_buf(vim.bo.filetype)
      return
    end

    if args.event == 'WinEnter' then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        vim.wo[win].cursorline = false
      end
      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_get_config(win).relative == '' then
        if vim.g.normal_winid_rec == nil then
          vim.g.normal_winid_rec = { prev = win, current = win }
        else
          vim.g.normal_winid_rec =
            { prev = vim.g.normal_winid_rec.current, current = win }
        end
      end
    end

    vim.wo.number = true
    vim.wo.list = true
    vim.wo.cursorline = true
    vim.wo.signcolumn = 'yes:1'
  end,
})

vim.api.nvim_create_autocmd('WinClosed', {
  callback = function(args)
    local closed_win = assert(tonumber(args.match))
    if vim.api.nvim_win_get_config(closed_win).relative ~= '' then
      return
    end
    local prev_win = vim.g.normal_winid_rec.prev
    if vim.api.nvim_win_is_valid(prev_win) then
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(prev_win) then
          vim.api.nvim_set_current_win(prev_win)
        end
      end)
    end
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
  dev = {
    path = '~/NixConfig/nvim/lua',
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
