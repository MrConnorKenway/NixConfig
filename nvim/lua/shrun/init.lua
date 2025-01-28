local M = {}

---@class shrun.Task
---@field id integer
---@field cmd string
---@field status string
---@field buf_id integer
---@field term_id integer
---@field job_id integer
---@field output_tail string
---@field output_line_num integer?

---@class shrun.TaskRange
---@field start_line integer?
---@field end_line integer?
---@field task_id integer

---all registered tasks
---@type shrun.Task[]
local all_tasks = {}

---@class shrun.Sidebar
---@field bufnr integer
---@field task_ranges shrun.TaskRange[] -- map from line range to task
---@field focused_task_range shrun.TaskRange?
---@field tasklist_winid integer? -- when winid == nil, the window is closed
---@field tasklist_cursor integer[]?
---@field taskout_winid integer? -- when winid == nil, the window is closed

---@type shrun.Sidebar
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
  TaskFAILED = 'DiagnosticError',
  TaskFocus = 'CursorLine',
  TaskName = 'Title',
  TaskOutPrefix = 'Comment'
}

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
    line_hl_group = default_highlights.TaskFocus,
    end_row = task_range.end_line - 1,
  })
end

---@param lines string[]
---@param highlights {[1]: string, [2]: integer, [3]: integer, [4]: integer}
---                   group name,  start row,    start col,    end col
---@param task shrun.Task
local function render_task(lines, highlights, task)
  local status_len = string.len(task.status)
  local cmd_offset = status_len + 2 -- 2 == len(': ')

  table.insert(lines, task.status .. ': ' .. task.cmd)
  table.insert(highlights, {
    default_highlights['Task' .. task.status],
    #lines, 0, status_len
  })
  table.insert(highlights, {
    default_highlights.TaskName, #lines, cmd_offset, cmd_offset + string.len(task.cmd)
  })
  table.insert(lines, out_prefix .. task.output_tail)
  task.output_line_num = #lines
  table.insert(highlights, { default_highlights.TaskOutPrefix, #lines, 0, string.len(out_prefix) })
end

---@param bufnr integer
local function switch_task_out_panel(bufnr)
  vim.wo[sidebar.taskout_winid].winfixbuf = false
  vim.api.nvim_win_set_buf(sidebar.taskout_winid, bufnr)
  vim.wo[sidebar.taskout_winid].winfixbuf = true
end

---caller should ensure that sidebar ~= nil
local function render_sidebar()
  local ns = vim.api.nvim_create_namespace('shrun_sidebar')
  local lines = {}
  local highlights = {}
  local separator = string.rep(separator_stem, vim.o.columns)

  sidebar.task_ranges = {}
  for i = #all_tasks, 1, -1 do
    local task = all_tasks[i]
    ---@type shrun.TaskRange
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
---@return shrun.TaskRange?
local function sidebar_get_task_range_from_line(lnum)
  for _, task_range in ipairs(sidebar.task_ranges) do
    if task_range.end_line >= lnum then
      return task_range
    end
  end
  return nil
end

---caller should ensure that task output panel is opened and the buffer shown in
---panel has buffer id of `bufnr`
---@param bufnr integer
local function scroll_terminal_to_tail(bufnr)
  local line_cnt = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(sidebar.taskout_winid, { line_cnt, 0 })
end

---since `sidebar_on_cursor_move` is called by a buffer local autocmd, it seems
---that we don't need to check if current window is task list window
local function sidebar_on_cursor_move()
  local lnum = vim.api.nvim_win_get_cursor(sidebar.tasklist_winid)[1]
  ---@type shrun.TaskRange?
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
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(winid),
    once = true,
    callback = function()
      if sidebar.tasklist_winid then
        sidebar.tasklist_cursor = vim.api.nvim_win_get_cursor(sidebar.tasklist_winid)
        vim.api.nvim_win_close(sidebar.tasklist_winid, false)
      end
      sidebar.tasklist_winid = nil
      sidebar.taskout_winid = nil
    end
  })
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
  local width
  local height

  if sidebar and sidebar.tasklist_winid then
    width = vim.api.nvim_win_get_width(sidebar.tasklist_winid)
    height = vim.api.nvim_win_get_height(sidebar.tasklist_winid)
  else
    width = tasklist_width
    height = tasklist_height
  end

  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = 'editor',
    width = vim.o.columns - width,
    height = height,
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

---@param task shrun.Task
local function start_task(task)
  task.buf_id = vim.api.nvim_create_buf(false, true)
  task.status = 'RUNNING'
  task.output_tail = ''

  run_in_tmp_win(task.buf_id, function()
    task.term_id = vim.api.nvim_open_term(task.buf_id, {
      on_input = function(_, _, _, data)
        pcall(vim.api.nvim_chan_send, task.job_id, data)
      end
    })
  end)

  task.job_id = vim.fn.jobstart(task.cmd, {
    pty = true,
    on_stdout = function(_, out)
      for i = #out, 1, -1 do
        if out[i]:len() > 0 then
          task.output_tail = out[i]
              :gsub('\r$', '')
              :gsub('\x1b%[[%d;]*m', '')
              :gsub('\x1b%[%d*K', '')
          break
        end
      end
      if sidebar.tasklist_winid and task.output_line_num then
        vim.bo[sidebar.bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(sidebar.bufnr, task.output_line_num - 1, task.output_line_num, true,
          { out_prefix .. task.output_tail })
        vim.bo[sidebar.bufnr].modifiable = false
        vim.bo[sidebar.bufnr].modified = false
        local ns = vim.api.nvim_create_namespace('shrun_sidebar')
        vim.api.nvim_buf_add_highlight(sidebar.bufnr, ns, default_highlights.TaskOutPrefix, task.output_line_num - 1, 0,
          out_prefix:len())
      end
      vim.api.nvim_chan_send(task.term_id, table.concat(out, '\r\n'))
    end,
    on_exit = function(_, exit_code, _)
      if exit_code == 0 then
        task.status = 'SUCCESS'
        if sidebar then
          render_sidebar()
        end
        vim.notify(task.cmd .. ' success', vim.log.levels.INFO, { timeout = 2000 })
      else
        task.status = 'FAILED'
        if sidebar then
          render_sidebar()
        end
        vim.notify(task.cmd .. ' failed', vim.log.levels.ERROR, { timeout = 2000 })
      end
      vim.api.nvim_chan_send(task.term_id, string.format('\n[ Process exited with %d ]', exit_code))
    end
  })

  vim.api.nvim_buf_set_name(task.buf_id, string.format('task %d:%s', task.job_id, task.cmd))
end

local function new_tasklist_buffer()
  local tasklist_bufnr = vim.api.nvim_create_buf(false, true)

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

    local task = all_tasks[range.task_id]
    if task.status == 'RUNNING' then
      return
    end

    local old_bufnr = task.buf_id
    local old_term = task.term_id

    start_task(task)
    render_sidebar()
    scroll_terminal_to_tail(task.buf_id)

    vim.fn.chanclose(old_term)
    vim.api.nvim_buf_delete(old_bufnr, {})
  end, { buffer = tasklist_bufnr })

  vim.api.nvim_create_autocmd('BufHidden', {
    buffer = tasklist_bufnr,
    callback = function()
      sidebar.tasklist_cursor = vim.api.nvim_win_get_cursor(sidebar.tasklist_winid)
      if sidebar.taskout_winid then
        vim.api.nvim_win_close(sidebar.taskout_winid, false)
      end
      sidebar.tasklist_winid = nil
      sidebar.taskout_winid = nil
    end
  })

  vim.api.nvim_create_autocmd('BufUnload', {
    buffer = tasklist_bufnr,
    callback = function()
      -- set to -1 so that the nvim_buf_is_valid check inside `ListTask` command
      -- returns false and new task list buffer is created
      sidebar.bufnr = -1
    end
  })

  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = tasklist_bufnr,
    nested = false, -- TODO: do we need nested?
    callback = sidebar_on_cursor_move
  })

  return tasklist_bufnr
end

M.setup = function()
  vim.api.nvim_create_user_command('Task',
    function(cmd)
      local task = {
        id = #all_tasks + 1,
        cmd = cmd.args
      }

      start_task(task)
      table.insert(all_tasks, task)
      if sidebar then
        if vim.api.nvim_get_current_buf() == sidebar.bufnr then
          -- move cursor to the first line, and the CursorMoved autocmd will do
          -- the work for us
          vim.api.nvim_win_set_cursor(sidebar.tasklist_winid, { 1, 0 })
          -- we cannot wait CursorMoved event to trigger because the
          -- `scroll_terminal_to_tail` a few lines below needs the task panel to
          -- be switched
          switch_task_out_panel(task.buf_id)
        else
          sidebar.focused_task_range = { task_id = task.id }
        end
        if sidebar.tasklist_winid then
          render_sidebar()
          -- sidebar.tasklist_winid ~= nil iff. sidebar.taskout_winid ~= nil
          scroll_terminal_to_tail(task.buf_id)
        end
      end
    end,
    {
      complete = vim.fn.has('nvim-0.11') == 0 and 'shellcmd' or 'shellcmdline',
      nargs = '+',
      desc = 'Run task'
    })

  vim.api.nvim_create_user_command('ListTask', function()
      if not sidebar then
        sidebar = {
          bufnr = new_tasklist_buffer(),
          task_ranges = {}
        }
        render_sidebar()
      elseif not vim.api.nvim_buf_is_valid(sidebar.bufnr) then
        sidebar.bufnr = new_tasklist_buffer()
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
      if sidebar.tasklist_cursor then
        vim.api.nvim_win_set_cursor(tasklist_winid, sidebar.tasklist_cursor)
      end
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

---for development test purpose only
M.test = function()
  local timer = vim.uv.new_timer()
  local delay = 300
  local winid

  if not timer then
    return
  end

  local abort_tests_if_not = function(assertion)
    if not assertion then
      vim.uv.timer_stop(timer)
      vim.uv.close(timer)
      assert(assertion)
    end
  end

  local idx = 0

  --- The following commands will be executed sequentially with a delay of `delay`
  --- milliseconds in between. The string command will be called by `vim.cmd`.
  ---@type (string|function)[]
  local commands = {
    'tabnew',
    function()
      winid = vim.api.nvim_get_current_win()
    end,
    'Task sleep 1 && echo done',
    'ListTask',
    'Task ls',
    'Task seq 1 ' .. tasklist_height,
    function()
      -- since last command is newly executed, its output should scroll to bottom
      vim.api.nvim_set_current_win(sidebar.taskout_winid)
      abort_tests_if_not(vim.fn.line('w0') ~= '3')
      -- go back to beginning window to prepare for the next test
      vim.api.nvim_set_current_win(winid)
    end,
    'Task seq 1 ' .. tasklist_height,
    function()
      -- when running command outside of task panel, the output should also scroll
      -- to bottom
      vim.api.nvim_set_current_win(sidebar.taskout_winid)
      abort_tests_if_not(vim.fn.line('w0') ~= '3')
      vim.api.nvim_set_current_win(sidebar.tasklist_winid)
      vim.api.nvim_win_close(sidebar.tasklist_winid, false)
    end,
    'Task seq 1 ' .. tasklist_height,
    'ListTask',
    function()
      -- when running command with task panel closed and then open it, the output
      -- should also scroll to bottom
      vim.api.nvim_set_current_win(sidebar.taskout_winid)
      abort_tests_if_not(vim.fn.line('w0') ~= '3')
      vim.api.nvim_set_current_win(sidebar.tasklist_winid)
    end,
    '+2',
    'Task python --version',
    'Task tree',
    'ListTask',
    'normal! G',
    [[ call feedkeys("\<cr>") ]],
    function()
      -- if <cr> does restart the first task, then it should be running now
      abort_tests_if_not(sidebar.focused_task_range.task_id == 1)
      local task = all_tasks[sidebar.focused_task_range.task_id]
      local header = vim.api.nvim_buf_get_lines(sidebar.bufnr, sidebar.focused_task_range.start_line - 1,
        sidebar.focused_task_range.end_line, true)
      abort_tests_if_not(task.cmd:match('^sleep'))
      abort_tests_if_not(task.status == 'RUNNING')
      abort_tests_if_not(header[1]:match('^RUNNING: sleep'))
    end,
    '+5',
    'Task make',
    function()
      -- newly created task should be automatically focused and put in the front
      abort_tests_if_not(sidebar.focused_task_range.start_line == 1)
      abort_tests_if_not(all_tasks[sidebar.focused_task_range.task_id].cmd == 'make')
    end,
    'Task cat longline',
    'Task brew update',
    'wincmd c',
    'Task ls',
    'Task tree',
    'ListTask',
    '+2',
    '+5',
    'normal! gg',
    'normal! 16G7|',
    'wincmd p',
    function()
      abort_tests_if_not(sidebar.tasklist_winid ~= nil)
      abort_tests_if_not(sidebar.taskout_winid ~= nil)
      vim.api.nvim_set_current_win(sidebar.taskout_winid)
    end,
    'wincmd c',
    function()
      -- both window should be closed
      abort_tests_if_not(sidebar.tasklist_winid == nil)
      abort_tests_if_not(sidebar.taskout_winid == nil)
      abort_tests_if_not(vim.api.nvim_get_current_win() == winid)
    end,
    'ListTask',
    function()
      abort_tests_if_not(vim.api.nvim_get_current_win() == sidebar.tasklist_winid)
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      abort_tests_if_not(row == 16 and col == 6)
    end,
    'tabclose'
  }

  timer:start(delay, delay,
    vim.schedule_wrap(function()
      idx = idx + 1
      if idx > #commands then
        vim.uv.timer_stop(timer)
        vim.uv.close(timer)
        vim.notify('All tests passed', vim.log.levels.INFO, { timeout = 5000 })
        return
      end

      if type(commands[idx]) == 'string' then
        vim.cmd(commands[idx])
      else
        commands[idx]()
      end

      if vim.fn.empty(vim.v.errmsg) == 0 then
        vim.uv.timer_stop(timer)
        vim.uv.close(timer)
        return
      end
    end)
  )
end

return M
