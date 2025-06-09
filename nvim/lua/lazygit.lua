local home_dir = vim.uv.os_homedir()
local term_width = vim.o.columns
local term_height = vim.o.lines

local function lazygit(lazygit_args)
  local lazygit_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_create_autocmd('BufEnter', {
    buffer = lazygit_buf,
    callback = function()
      vim.cmd('startinsert')
    end,
  })
  local lazygit_win = vim.api.nvim_open_win(lazygit_buf, true, {
    relative = 'editor',
    width = vim.o.columns,
    height = vim.o.lines,
    style = 'minimal',
    row = math.floor((vim.o.lines - term_height) / 2),
    col = math.floor((vim.o.columns - term_width) / 2),
  })
  vim.wo[lazygit_win].winhighlight = 'NormalFloat:Normal'
  local args = {
    'lazygit',
    '-ucf',
    string.format(
      '%s/.config/lazygit/%s.yml,%s/.config/lazygit/config.yml',
      home_dir,
      vim.o.background,
      home_dir
    ),
    unpack(lazygit_args),
  }
  local lazygit_job = vim.fn.jobstart(args, {
    term = true,
    on_exit = function()
      if vim.api.nvim_win_is_valid(lazygit_win) then
        vim.api.nvim_win_close(lazygit_win, true)
      end
      vim.api.nvim_buf_delete(lazygit_buf, {})
    end,
  })
  vim.api.nvim_create_autocmd('BufLeave', {
    once = true,
    buffer = lazygit_buf,
    callback = function()
      vim.fn.jobstop(lazygit_job)
    end,
  })
end

vim.keymap.set('n', 'gl', function()
  lazygit {
    'log',
  }
end, { desc = 'Display lazygit log' })

vim.keymap.set('n', 'gs', function()
  lazygit {
    'status',
  }
end, { desc = 'Display lazygit status' })
