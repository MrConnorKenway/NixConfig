local M = {}

---@class Task
---@field id integer
---@field cmd string
---@field buf_id integer
---@field term_id integer
---@field job_id integer

---@type Task[]
local task_list = {}

---@class Sidebar
---@field bufnr integer
---@field task_lines {[1]: integer, [2]: Task} -- map from line number to task
---@field focused_task_id integer?
---@field tasklist_winid integer?
---@field taskout_winid integer?

---@class Sidebar
local sidebar

---@type integer?
local empty_task_output_buf

--TODO: make configurable
local tasklist_width = 32
local tasklist_height = 12
local separator_stem = '─'

M.get = function()
  return sidebar
end

local task_nr = 0

local function highlight_focused()
  local ns = vim.api.nvim_create_namespace('tasklist_focus')
  vim.api.nvim_buf_clear_namespace(sidebar.bufnr, ns, 0, -1)
  if not sidebar.focused_task_id then return end

  local start_lnum = 1
  for _, v in ipairs(sidebar.task_lines) do
    local end_lnum, task = v[1], v[2]
    if task.id == sidebar.focused_task_id then
      vim.api.nvim_buf_set_extmark(sidebar.bufnr, ns, start_lnum - 1, 0, {
        line_hl_group = "CursorLine",
        end_row = end_lnum - 1,
      })
    end
    start_lnum = end_lnum + 2 -- 2: we have a separator
  end
end

---@param lines string[]
---@param task Task
local function render_task(lines, task)
  table.insert(lines, 'RUNNING: ' .. task.cmd)
  table.insert(lines, 'out: ')
end

local function render_sidebar()
  local lines = {}
  local separator = string.rep(separator_stem, vim.o.columns)

  sidebar.task_lines = {}
  for i = #task_list, 1, -1 do
    local task = task_list[i]
    render_task(lines, task)
    table.insert(sidebar.task_lines, { #lines, task })
    if i > 1 then
      table.insert(lines, separator)
    end
  end

  vim.bo[sidebar.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(sidebar.bufnr, 0, -1, true, lines)
  vim.bo[sidebar.bufnr].modifiable = false
  vim.bo[sidebar.bufnr].modified = false

  highlight_focused()
end

---@param lnum integer
---@return Task?
local function sidebar_get_task_from_line(lnum)
  for _, v in ipairs(sidebar.task_lines) do
    -- end_lnum, task = v[1], v[2]
    if v[1] >= lnum then
      return v[2]
    end
  end
  return nil
end

local function sidebar_on_cursor_move(bufnr)
  local winid
  if vim.api.nvim_get_current_buf() == bufnr then
    winid = vim.api.nvim_get_current_win()
  else
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(winid)[1]
  ---@type Task?
  local task = sidebar_get_task_from_line(lnum)

  if not task or task.id == sidebar.focused_task_id then
    return
  end

  -- vim.api.nvim_exec_autocmds('User', {
  --   pattern = 'ListTaskHover',
  --   modeline = false,
  --   data = {
  --     task_id = task.id,
  --   },
  -- })
  sidebar.focused_task_id = task.id
  if vim.api.nvim_win_is_valid(sidebar.taskout_winid) then
    vim.api.nvim_win_set_buf(sidebar.taskout_winid, task.buf_id)
  end

  highlight_focused()
end

---@param buf_id integer the bufnr of task output buffer, i.e., Task.buf_id
local function new_task_output_window(buf_id)
  local winid = vim.api.nvim_open_win(buf_id, false,
    { split = 'right', width = vim.o.columns - tasklist_width })
  local default_opts = {
    winfixwidth = true,
    winfixheight = true,
    number = false,
    signcolumn = 'no',
    foldcolumn = '0',
    relativenumber = false,
    wrap = false,
    spell = false,
  }
  for k, v in pairs(default_opts) do
    vim.api.nvim_set_option_value(k, v, { scope = 'local', win = winid })
  end
  return winid
end

local function new_sidebar()
  local tasklist_bufnr = vim.api.nvim_create_buf(false, true)
  local task_lines = {}

  vim.api.nvim_buf_set_name(tasklist_bufnr, 'TaskList')

  vim.bo[tasklist_bufnr].filetype = 'tasklist'
  vim.bo[tasklist_bufnr].buftype = 'nofile'
  vim.bo[tasklist_bufnr].bufhidden = 'hide'
  vim.bo[tasklist_bufnr].buflisted = false
  vim.bo[tasklist_bufnr].swapfile = false
  vim.bo[tasklist_bufnr].modifiable = false

  vim.keymap.set('n', '<cr>', function()
    if vim.api.nvim_win_is_valid(sidebar.taskout_winid) then
      vim.api.nvim_set_current_win(sidebar.taskout_winid)
    else
      -- open task output panel if window is closed
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      local task = sidebar_get_task_from_line(lnum)
      if task then
        sidebar.taskout_winid = new_task_output_window(task.buf_id)
      end
    end
  end, { buffer = tasklist_bufnr })

  vim.api.nvim_create_autocmd('BufHidden', {
    buffer = tasklist_bufnr,
    callback = function()
      if vim.api.nvim_win_is_valid(sidebar.taskout_winid) then
        vim.api.nvim_win_close(sidebar.taskout_winid, false)
      end
      sidebar.tasklist_winid = nil
      sidebar.taskout_winid = nil
    end
  })

  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = tasklist_bufnr,
    nested = false, -- TODO: do we need nested?
    callback = function()
      sidebar_on_cursor_move(tasklist_bufnr)
    end
  })

  vim.api.nvim_create_autocmd('User', {
    pattern = 'TaskListUpdate',
    callback = function()
      render_sidebar()
    end
  })

  return {
    bufnr = tasklist_bufnr,
    task_lines = task_lines
  }
end

---Currently when calling `vim.api.nvim_open_term`, neovim's libvterm will use
---the width of current window to render terminal output, thus we have to create
---a temporary fullscreen window to mitigate such issu
---@param bufnr integer
---@param fn fun()
local function run_in_fullscreen_win(bufnr, fn)
  local start_winid = vim.api.nvim_get_current_win()
  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = 'editor',
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
    noautocmd = true,
  })
  vim.api.nvim_set_current_win(winid)
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    vim.api.nvim_err_writeln(err)
  end
  vim.api.nvim_win_close(winid, false)
  vim.api.nvim_set_current_win(start_winid)
end

M.setup = function()
  vim.api.nvim_create_user_command('Task',
    function(cmd)
      ---@class Task
      local task = {}
      task_nr = task_nr + 1
      task.id = task_nr
      task.cmd = cmd.args
      task.buf_id = vim.api.nvim_create_buf(false, true)

      run_in_fullscreen_win(task.buf_id, function()
        task.term_id = vim.api.nvim_open_term(task.buf_id, {
          on_input = function(_, _, _, data)
            vim.api.nvim_chan_send(task.job_id, data)
          end
        })
      end)
      task.job_id = vim.fn.jobstart(task.cmd, {
        pty = true,
        on_stdout = function(job_id, out)
          vim.api.nvim_chan_send(task.term_id, table.concat(out, '\r\n'))
        end,
        on_exit = function(job_id, data, event)
          if data == 0 then
            vim.notify(job_id .. ' success', vim.log.levels.TRACE)
          else
            vim.notify(job_id .. ' failed', vim.log.levels.ERROR)
          end
        end
      })
      vim.api.nvim_buf_set_name(task.buf_id, string.format('task %d:%s', task.job_id, cmd.args))
      table.insert(task_list, task)
      if sidebar then
        render_sidebar()
      end
      vim.notify(vim.inspect(task_list), vim.log.levels.DEBUG)
    end,
    {
      complete = vim.fn.has('nvim-0.11') == 0 and 'shellcmd' or 'shellcmdline',
      nargs = '+',
      desc = 'Run task'
    })

  vim.api.nvim_create_user_command('ListTask', function()
      if not sidebar then
        sidebar = new_sidebar()
        render_sidebar()
      end
      if sidebar.tasklist_winid then
        return
      end
      if not empty_task_output_buf then
        empty_task_output_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(empty_task_output_buf, 'Task Output')
        vim.bo[empty_task_output_buf].buftype = 'nofile'
        vim.bo[empty_task_output_buf].bufhidden = 'hide'
        vim.bo[empty_task_output_buf].buflisted = false
        vim.bo[empty_task_output_buf].swapfile = false
        vim.bo[empty_task_output_buf].modifiable = false
      end
      vim.cmd [[botright split]]
      local tasklist_winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_height(tasklist_winid, tasklist_height)
      vim.api.nvim_win_set_width(tasklist_winid, tasklist_width)
      vim.api.nvim_win_set_buf(tasklist_winid, sidebar.bufnr)
      local default_opts = {
        winfixwidth = true,
        winfixheight = true,
        number = false,
        signcolumn = 'no',
        foldcolumn = '0',
        relativenumber = false,
        wrap = false,
        spell = false,
      }
      for k, v in pairs(default_opts) do
        vim.api.nvim_set_option_value(k, v, { scope = 'local', win = tasklist_winid })
      end
      sidebar.tasklist_winid = tasklist_winid
      if sidebar.focused_task_id then
        sidebar.taskout_winid = new_task_output_window(task_list[sidebar.focused_task_id].buf_id)
      else
        sidebar.taskout_winid = new_task_output_window(empty_task_output_buf)
      end
    end,
    {
      nargs = 0,
      desc = 'Show task list'
    })
end

return M
