local M = {}

---@class Task
---@field id integer
---@field cmd string
---@field status string
---@field buf_id integer
---@field term_id integer
---@field job_id integer

---@class TaskRange
---@field start_line integer?
---@field end_line integer?
---@field task_id integer

---all registered tasks
---@type Task[]
local all_tasks = {}

---@class Sidebar
---@field bufnr integer
---@field task_ranges TaskRange[] -- map from line range to task
---@field focused_task_range TaskRange?
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
local out_prefix = 'out: '
local default_highlights = {
  TaskRUNNING = 'Constant',
  TaskSUCCESS = 'DiagnosticOk',
  TaskFAILED = 'DiagnosticError'
}

local task_nr = 0

local function highlight_focused()
  local ns = vim.api.nvim_create_namespace('tasklist_focus')
  vim.api.nvim_buf_clear_namespace(sidebar.bufnr, ns, 0, -1)

  local task_range = sidebar.focused_task_range
  if not task_range then return end

  if not task_range.end_line then
    -- slow path
    for _, r in ipairs(sidebar.task_ranges) do
      if r.task_id == task_range.task_id then
        task_range = r
        break
      end
    end
  end

  vim.api.nvim_buf_set_extmark(sidebar.bufnr, ns, task_range.start_line - 1, 0, {
    line_hl_group = "CursorLine",
    end_row = task_range.end_line - 1,
  })
end

---@param lines string[]
---@param highlights {[1]: string, [2]: integer, [3]: integer, [4]: integer}
---                   group name,  start row,    start col,    end col
---@param task Task
local function render_task(lines, highlights, task)
  local status_len = string.len(task.status)
  local cmd_offset = status_len + 2 -- 2 == len(': ')

  table.insert(lines, task.status .. ': ' .. task.cmd)
  table.insert(highlights, {
    default_highlights['Task' .. task.status],
    #lines, 0, status_len
  })
  table.insert(highlights, {
    'Title', #lines, cmd_offset, cmd_offset + string.len(task.cmd)
  })
  table.insert(lines, out_prefix)
  table.insert(highlights, { 'Comment', #lines, 0, string.len(out_prefix) })
end

---@param bufnr integer
local function switch_task_out_panel(bufnr)
  vim.wo[sidebar.taskout_winid].winfixbuf = false
  vim.api.nvim_win_set_buf(sidebar.taskout_winid, bufnr)
  vim.wo[sidebar.taskout_winid].winfixbuf = true
end

local function render_sidebar()
  local ns = vim.api.nvim_create_namespace('shrun_sidebar')
  local lines = {}
  local highlights = {}
  local separator = string.rep(separator_stem, vim.o.columns)

  sidebar.task_ranges = {}
  for i = #all_tasks, 1, -1 do
    local task = all_tasks[i]
    ---@type TaskRange
    local task_range = { start_line = #lines + 1, end_line = -1, task_id = task.id }
    render_task(lines, highlights, task)
    task_range.end_line = #lines
    table.insert(sidebar.task_ranges, task_range)
    if i > 1 then
      table.insert(lines, separator)
      table.insert(highlights, { 'FloatBorder', #lines, 0, vim.o.columns })
    end
  end

  vim.bo[sidebar.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(sidebar.bufnr, 0, -1, true, lines)
  vim.bo[sidebar.bufnr].modifiable = false
  vim.bo[sidebar.bufnr].modified = false

  for _, hl in ipairs(highlights) do
    local group, lnum, col_start, col_end = unpack(hl)
    vim.api.nvim_buf_add_highlight(sidebar.bufnr, ns, group, lnum - 1, col_start, col_end)
  end

  if not sidebar.tasklist_winid then
    return
  end

  highlight_focused()
  if sidebar.taskout_winid and sidebar.focused_task_range then
    switch_task_out_panel(all_tasks[sidebar.focused_task_range.task_id].buf_id)
  end
end

---@param lnum integer
---@return TaskRange?
local function sidebar_get_task_range_from_line(lnum)
  for _, task_range in ipairs(sidebar.task_ranges) do
    if task_range.end_line >= lnum then
      return task_range
    end
  end
  return nil
end

local function scroll_terminal_to_tail()
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(sidebar.taskout_winid)
  vim.cmd [[normal! G]]
  vim.api.nvim_set_current_win(winid)
end

local function sidebar_on_cursor_move(bufnr)
  local winid
  if vim.api.nvim_get_current_buf() == bufnr then
    winid = vim.api.nvim_get_current_win()
  else
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(winid)[1]
  ---@type TaskRange?
  local range = sidebar_get_task_range_from_line(lnum)

  if not range then
    return
  end

  if sidebar.focused_task_range and sidebar.focused_task_range == range then
    return
  end

  sidebar.focused_task_range = range
  if sidebar.taskout_winid then
    switch_task_out_panel(all_tasks[range.task_id].buf_id)
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
    winfixbuf = true,
    number = false,
    signcolumn = 'no',
    foldcolumn = '0',
    relativenumber = false,
    wrap = true,
    spell = false,
  }
  for k, v in pairs(default_opts) do
    vim.api.nvim_set_option_value(k, v, { scope = 'local', win = winid })
  end
  return winid
end

---Currently when calling `vim.api.nvim_open_term`, neovim's libvterm will use
---the width of current window to render terminal output, thus we have to create
---a temporary window that has equal size with task output panel to mitigate such
---issue
---@param bufnr integer
---@param fn fun()
local function run_in_tmp_win(bufnr, fn)
  local start_winid = vim.api.nvim_get_current_win()
  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = 'editor',
    width = vim.o.columns - tasklist_width,
    height = tasklist_height,
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

---@param task Task
local function start_task(task)
  task.buf_id = vim.api.nvim_create_buf(false, true)
  task.status = 'RUNNING'

  run_in_tmp_win(task.buf_id, function()
    task.term_id = vim.api.nvim_open_term(task.buf_id, {
      on_input = function(_, _, _, data)
        pcall(vim.api.nvim_chan_send, task.job_id, data)
      end
    })
  end)

  task.job_id = vim.fn.jobstart(task.cmd, {
    pty = true,
    on_stdout = function(job_id, out)
      vim.api.nvim_chan_send(task.term_id, table.concat(out, '\r\n'))
    end,
    on_exit = function(job_id, exit_code, event)
      if exit_code == 0 then
        task.status = 'SUCCESS'
        if sidebar then
          render_sidebar()
        end
        vim.notify(job_id .. ' success', vim.log.levels.TRACE)
      else
        task.status = 'FAILED'
        if sidebar then
          render_sidebar()
        end
        vim.notify(job_id .. ' failed', vim.log.levels.ERROR)
      end
      vim.api.nvim_chan_send(task.term_id, string.format('\n[ Process exited with %d ]', exit_code))
    end
  })

  vim.api.nvim_buf_set_name(task.buf_id, string.format('task %d:%s', task.job_id, task.cmd))
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
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local range = sidebar_get_task_range_from_line(lnum)

    if not range then return end

    if sidebar.taskout_winid then
      local task = all_tasks[range.task_id]
      if task.status == 'RUNNING' then
        return
      end

      local old_bufnr = task.buf_id
      local old_term = task.term_id

      start_task(task)
      switch_task_out_panel(all_tasks[range.task_id].buf_id)
      scroll_terminal_to_tail()

      vim.cmd(string.format('call chanclose(%d)', old_term))
      vim.api.nvim_buf_delete(old_bufnr, {})
    else
      -- open task output panel if window is closed
      sidebar.taskout_winid = new_task_output_window(all_tasks[range.task_id].buf_id)
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

M.setup = function()
  vim.api.nvim_create_user_command('Task',
    function(cmd)
      ---@class Task
      local task = {}
      task_nr = task_nr + 1
      task.id = task_nr
      task.cmd = cmd.args

      start_task(task)
      table.insert(all_tasks, task)
      if sidebar then
        if vim.api.nvim_get_current_buf() == sidebar.bufnr then
          -- move cursor to the first line, and the CursorMoved autocmd will do
          -- the work for us
          vim.api.nvim_win_set_cursor(sidebar.tasklist_winid, { 1, 0 })
        else
          sidebar.focused_task_range = {
            start_line = nil,
            end_line = nil,
            task_id = task.id
          }
        end
        render_sidebar()
        scroll_terminal_to_tail()
      end
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
      if sidebar.focused_task_range then
        local bufnr = all_tasks[sidebar.focused_task_range.task_id].buf_id
        sidebar.taskout_winid = new_task_output_window(bufnr)
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
