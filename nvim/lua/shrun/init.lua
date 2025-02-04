local M = {}

---@class shrun.Task
---@field id integer
---@field cmd string
---@field view vim.fn.winsaveview.ret
---@field status string
---@field buf_id integer
---@field term_id integer
---@field job_id integer
---@field output_tail string
---@field output_line_num integer?
---@field no_follow_term_output boolean?

---@class shrun.TaskRange
---@field start_line integer?
---@field end_line integer?
---@field task_id integer

---all registered tasks
---@type shrun.Task[]
local all_tasks = {}

---@class shrun.TaskPanel
---@field sidebar_bufnr integer
---@field task_ranges shrun.TaskRange[] -- map from line range to task
---@field focused_task_range shrun.TaskRange?
---@field sidebar_winid integer? -- when winid == nil, the window is closed
---@field sidebar_cursor integer[]?
---@field task_output_winid integer? -- when winid == nil, the window is closed
---
---  Task Panel:
---  ╭─────────────────────────────────────────────────────╮
---  │               │                                     │
---  │               │                                     │
---  │               │                                     │
---  │    Sidebar    │             Task Output             │
---  │               │                                     │
---  │               │                                     │
---  │               │                                     │
---  ╰─────────────────────────────────────────────────────╯

---@type shrun.TaskPanel
local task_panel

local sidebar_hl_ns = vim.api.nvim_create_namespace('shrun_sidebar')
local sidebar_focus_hl_ns = vim.api.nvim_create_namespace('shrun_sidebar_focus')

---@type integer?
local empty_task_output_buf

--TODO: make configurable
local sidebar_width = 32
local sidebar_height = 12
local separator_stem = '─'
local out_prefix = 'out: '
local default_highlights = {
  TaskRUNNING = 'Constant',
  TaskSUCCESS = 'DiagnosticOk',
  TaskFAILED = 'DiagnosticError',
  TaskFocus = 'CursorLine',
  TaskName = 'Title',
  TaskOutPrefix = 'Comment',
}

---@param task shrun.Task
---@param row_offset integer zero-based indexing start row
local function render_task(task, row_offset)
  local lines = {} ---@type string[]
  ---@type {[1]: string, [2]: integer, [3]: integer, [4]: integer}[]
  ---       group name,  start row,    start col,    end col
  local highlights = {}
  local status_len = string.len(task.status)
  local cmd_offset = status_len + 2 -- 2 == len(': ')

  table.insert(lines, task.status .. ': ' .. task.cmd)
  table.insert(highlights, {
    default_highlights['Task' .. task.status],
    row_offset + #lines,
    0,
    status_len,
  })
  table.insert(highlights, {
    default_highlights.TaskName,
    row_offset + #lines,
    cmd_offset,
    cmd_offset + string.len(task.cmd),
  })
  table.insert(lines, out_prefix .. task.output_tail)
  task.output_line_num = row_offset + #lines
  table.insert(highlights, {
    default_highlights.TaskOutPrefix,
    row_offset + #lines,
    0,
    string.len(out_prefix),
  })

  return lines, highlights
end

---caller should ensure that task output panel is opened and the buffer shown in
---panel has buffer id of `bufnr`
---@param bufnr integer
local function scroll_terminal_to_tail(bufnr)
  local line_cnt = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(task_panel.task_output_winid, { line_cnt, 0 })
end

---@param task shrun.Task
local function switch_task_out_panel(task)
  vim.wo[task_panel.task_output_winid].winfixbuf = false
  vim.api.nvim_win_set_buf(task_panel.task_output_winid, task.buf_id)
  vim.wo[task_panel.task_output_winid].winfixbuf = true

  if not task.no_follow_term_output then
    scroll_terminal_to_tail(task.buf_id)
  else
    vim.api.nvim_win_call(task_panel.task_output_winid, function()
      vim.fn.winrestview(task.view)
    end)
  end
end

local function highlight_focused()
  vim.api.nvim_buf_clear_namespace(
    task_panel.sidebar_bufnr,
    sidebar_focus_hl_ns,
    0,
    -1
  )

  local task_range = task_panel.focused_task_range
  if not task_range then
    return
  end

  if not task_range.end_line then
    -- slow path
    for _, r in ipairs(task_panel.task_ranges) do
      if r.task_id == task_range.task_id then
        task_range = r
        break
      end
    end
  end

  vim.api.nvim_buf_set_extmark(
    task_panel.sidebar_bufnr,
    sidebar_focus_hl_ns,
    task_range.start_line - 1,
    0,
    {
      line_hl_group = default_highlights.TaskFocus,
      end_row = task_range.end_line - 1,
    }
  )

  if task_panel.task_output_winid and task_panel.focused_task_range then
    switch_task_out_panel(all_tasks[task_panel.focused_task_range.task_id])
  end
end

local function redraw_panel(lines, highlights, start_line, end_line)
  vim.bo[task_panel.sidebar_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(
    task_panel.sidebar_bufnr,
    start_line,
    end_line,
    true,
    lines
  )
  vim.bo[task_panel.sidebar_bufnr].modifiable = false
  vim.bo[task_panel.sidebar_bufnr].modified = false

  for _, hl in ipairs(highlights) do
    local group, row_start, col_start, col_end = unpack(hl)
    vim.api.nvim_buf_add_highlight(
      task_panel.sidebar_bufnr,
      sidebar_hl_ns,
      group,
      row_start - 1,
      col_start,
      col_end
    )
  end

  if task_panel.sidebar_winid then
    highlight_focused()
  end
end

---@param task shrun.Task
local function partial_render_sidebar(task)
  local task_range = task_panel.task_ranges[task.id]

  local lines, highlights = render_task(task, task_range.start_line - 1)

  redraw_panel(
    lines,
    highlights,
    task_range.start_line - 1,
    task_range.end_line
  )
end

---caller should ensure that `task_panel` ~= nil
local function render_sidebar_from_scratch()
  local lines = {}
  local highlights = {}
  local separator = string.rep(separator_stem, vim.o.columns)

  task_panel.task_ranges = {}
  for i = #all_tasks, 1, -1 do
    local task = all_tasks[i]
    local task_lines, task_highlights = render_task(task, #lines)
    task_panel.task_ranges[i] = {
      start_line = #lines + 1,
      end_line = #lines + #task_lines,
      task_id = task.id,
    }
    vim.list_extend(lines, task_lines)
    vim.list_extend(highlights, task_highlights)
    if i > 1 then
      table.insert(lines, separator)
      table.insert(highlights, { 'FloatBorder', #lines, 0, vim.o.columns })
    end
  end

  redraw_panel(lines, highlights, 0, -1)
end

---@param lnum integer
---@return shrun.TaskRange?
local function sidebar_get_task_range_from_line(lnum)
  for _, task_range in ipairs(task_panel.task_ranges) do
    if task_range.start_line <= lnum then
      return task_range
    end
  end
  return nil
end

---since `sidebar_on_cursor_move` is called by a buffer local autocmd, it seems
---that we don't need to check if current window is task list window
local function sidebar_on_cursor_move()
  local lnum = vim.api.nvim_win_get_cursor(task_panel.sidebar_winid)[1]
  ---@type shrun.TaskRange?
  local range = sidebar_get_task_range_from_line(lnum)

  if not range then
    return
  end

  if
    task_panel.focused_task_range and task_panel.focused_task_range == range
  then
    return
  end

  task_panel.focused_task_range = range
  highlight_focused()
end

---@param buf_id integer the bufnr of task output buffer, i.e., Task.buf_id
local function new_task_output_window(buf_id)
  local winid = vim.api.nvim_open_win(
    buf_id,
    false,
    { split = 'right', width = vim.o.columns - sidebar_width }
  )
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
      task_panel.task_output_winid = nil
      vim.schedule(function()
        if task_panel.sidebar_winid then
          vim.api.nvim_win_hide(task_panel.sidebar_winid)
        end
      end)
    end,
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

  if task_panel and task_panel.sidebar_winid then
    width = vim.api.nvim_win_get_width(task_panel.sidebar_winid)
    height = vim.api.nvim_win_get_height(task_panel.sidebar_winid)
  else
    width = sidebar_width
    height = sidebar_height
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
---@param restart boolean?
local function start_task(task, restart)
  if not restart then
    -- reuse task output buffer
    task.buf_id = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_create_autocmd('CursorMoved', {
      buffer = task.buf_id,
      callback = function()
        -- current buffer must be task's output buffer and current window must be
        -- task output window
        local row = vim.api.nvim_win_get_cursor(task_panel.task_output_winid)[1]
        -- if user moves cursor to non bottom, it is reasonable to assume that user
        -- wants to disable automatically scrolling and keeps the cursor fixed
        if row < vim.api.nvim_buf_line_count(task.buf_id) then
          task.no_follow_term_output = true
          task.view = vim.fn.winsaveview()
        else
          task.no_follow_term_output = false
        end
      end,
    })
  end
  task.status = 'RUNNING'
  task.output_tail = ''

  run_in_tmp_win(task.buf_id, function()
    task.term_id = vim.api.nvim_open_term(task.buf_id, {
      on_input = function(_, _, _, data)
        pcall(vim.api.nvim_chan_send, task.job_id, data)
      end,
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
      if task_panel and task.output_line_num then
        partial_render_sidebar(task)
      end
      vim.api.nvim_chan_send(task.term_id, table.concat(out, '\r\n'))
    end,
    on_exit = function(_, exit_code, _)
      if exit_code == 0 then
        task.status = 'SUCCESS'
        if task_panel then
          partial_render_sidebar(task)
        end
        --TODO: currently relies on Snacks.nvim's markdown support to change the
        --style, not a perfect solution
        vim.notify(
          task.cmd .. ' `SUCCESS`',
          vim.log.levels.INFO,
          { timeout = 2000 }
        )
        vim.api.nvim_chan_send(
          task.term_id,
          ('\n[ Process exited with \x1b[32m%d\x1b[m ]'):format(exit_code)
        )
      else
        task.status = 'FAILED'
        if task_panel then
          partial_render_sidebar(task)
        end
        --TODO: currently relies on Snacks.nvim's markdown support to change the
        --style, not a perfect solution
        vim.notify(
          task.cmd .. ' **FAILED**',
          vim.log.levels.ERROR,
          { timeout = 2000 }
        )
        vim.api.nvim_chan_send(
          task.term_id,
          ('\n[ Process exited with \x1b[31m%d\x1b[m ]'):format(exit_code)
        )
      end
    end,
  })

  vim.api.nvim_buf_set_name(
    task.buf_id,
    string.format('task %d:%s', task.job_id, task.cmd)
  )
end

local function restart_task()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local range = sidebar_get_task_range_from_line(lnum)

  if not range then
    return
  end

  local task = all_tasks[range.task_id]
  if task.status == 'RUNNING' then
    return
  end

  -- move cursor to the bottom to prevent "[Terminal closed]" message
  vim.api.nvim_chan_send(task.term_id, ('\x1b[%d;f'):format(vim.o.lines))
  vim.fn.chanclose(task.term_id)

  vim.bo[task.buf_id].modifiable = true
  vim.api.nvim_buf_set_lines(task.buf_id, 0, -1, false, {})
  vim.bo[task.buf_id].modifiable = false
  vim.bo[task.buf_id].modified = false

  start_task(task, true)

  partial_render_sidebar(task)
end

local function new_sidebar_buffer()
  local sidebar_bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_name(sidebar_bufnr, 'Shrun Sidebar')

  vim.bo[sidebar_bufnr].filetype = 'shrun_sidebar'
  vim.bo[sidebar_bufnr].buftype = 'nofile'
  vim.bo[sidebar_bufnr].bufhidden = 'hide'
  vim.bo[sidebar_bufnr].buflisted = false
  vim.bo[sidebar_bufnr].swapfile = false
  vim.bo[sidebar_bufnr].modifiable = false

  vim.keymap.set('n', '<cr>', restart_task, { buffer = sidebar_bufnr })

  vim.api.nvim_create_autocmd('BufHidden', {
    buffer = sidebar_bufnr,
    callback = function()
      task_panel.sidebar_cursor =
        vim.api.nvim_win_get_cursor(task_panel.sidebar_winid)
      task_panel.sidebar_winid = nil
      vim.schedule(function()
        if task_panel.task_output_winid then
          vim.api.nvim_win_hide(task_panel.task_output_winid)
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd('BufUnload', {
    buffer = sidebar_bufnr,
    callback = function()
      -- set to -1 so that the nvim_buf_is_valid check inside `ListTask` command
      -- returns false and new task list buffer is created
      task_panel.sidebar_bufnr = -1
    end,
  })

  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = sidebar_bufnr,
    nested = false, -- TODO: do we need nested?
    callback = sidebar_on_cursor_move,
  })

  return sidebar_bufnr
end

M.display_panel = function()
  if not task_panel then
    task_panel = {
      sidebar_bufnr = new_sidebar_buffer(),
      task_ranges = {},
    }
    render_sidebar_from_scratch()
  elseif not vim.api.nvim_buf_is_valid(task_panel.sidebar_bufnr) then
    task_panel.sidebar_bufnr = new_sidebar_buffer()
    render_sidebar_from_scratch()
  end

  if task_panel.sidebar_winid then
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
  vim.cmd([[botright split]])
  local sidebar_winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(sidebar_winid, sidebar_height)
  vim.api.nvim_win_set_width(sidebar_winid, sidebar_width)
  vim.api.nvim_win_set_buf(sidebar_winid, task_panel.sidebar_bufnr)
  if task_panel.sidebar_cursor then
    vim.api.nvim_win_set_cursor(sidebar_winid, task_panel.sidebar_cursor)
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
    vim.api.nvim_set_option_value(
      k,
      v,
      { scope = 'local', win = sidebar_winid }
    )
  end
  task_panel.sidebar_winid = sidebar_winid
  if task_panel.focused_task_range then
    local task = all_tasks[task_panel.focused_task_range.task_id]
    task_panel.task_output_winid = new_task_output_window(task.buf_id)
    if task.no_follow_term_output then
      vim.api.nvim_win_call(task_panel.task_output_winid, function()
        vim.fn.winrestview(task.view)
      end)
    else
      scroll_terminal_to_tail(task.buf_id)
    end
  else
    task_panel.task_output_winid = new_task_output_window(empty_task_output_buf)
  end
end

M.toggle_panel = function()
  if task_panel and task_panel.sidebar_winid then
    vim.api.nvim_win_hide(task_panel.sidebar_winid)
    return
  end

  M.display_panel()
end

M.setup = function()
  vim.api.nvim_create_user_command('Task', function(cmd)
    local task = {
      id = #all_tasks + 1,
      cmd = cmd.args,
    }

    start_task(task)
    table.insert(all_tasks, task)
    if task_panel then
      task_panel.focused_task_range = { task_id = task.id }

      local lines, highlights = render_task(task, 0)
      task_panel.task_ranges[task.id] =
        { start_line = 1, end_line = #lines, task_id = task.id }
      if #task_panel.task_ranges > 1 then
        local separator = string.rep(separator_stem, vim.o.columns)
        table.insert(lines, separator)
        table.insert(highlights, { 'FloatBorder', #lines, 0, vim.o.columns })
        for i = 1, #task_panel.task_ranges - 1 do
          local r = task_panel.task_ranges[i]
          r.start_line = r.start_line + #lines
          r.end_line = r.end_line + #lines
        end
      end

      vim.bo[task_panel.sidebar_bufnr].modifiable = true
      if #task_panel.task_ranges == 1 then
        vim.api.nvim_buf_set_lines(task_panel.sidebar_bufnr, 0, -1, true, lines)
      else
        vim.api.nvim_buf_set_lines(task_panel.sidebar_bufnr, 0, 0, true, lines)
      end
      vim.bo[task_panel.sidebar_bufnr].modifiable = false
      vim.bo[task_panel.sidebar_bufnr].modified = false

      for _, hl in ipairs(highlights) do
        local group, lnum, col_start, col_end = unpack(hl)
        vim.api.nvim_buf_add_highlight(
          task_panel.sidebar_bufnr,
          sidebar_hl_ns,
          group,
          lnum - 1,
          col_start,
          col_end
        )
      end

      if task_panel.sidebar_winid then
        vim.api.nvim_win_set_cursor(task_panel.sidebar_winid, { 1, 0 })
        highlight_focused()
      else
        -- task list panel is not opened, record the cursor here and defer the
        -- cursor update after `ListTask`
        task_panel.sidebar_cursor = { 1, 0 }
      end
    end
  end, {
    complete = vim.fn.has('nvim-0.11') == 0 and 'shellcmd' or 'shellcmdline',
    nargs = '+',
    desc = 'Run task',
  })

  vim.api.nvim_create_user_command('ListTask', M.display_panel, {
    nargs = 0,
    desc = 'Show sidebar',
  })

  vim.keymap.set({ 'n', 'i' }, '<D-r>', M.toggle_panel)
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

    ------------------ test running task before task panel is created ----------
    'Task sleep 1 && echo done',
    'ListTask',
    'Task ls',
    ------------------ end test ------------------------------------------------

    ------------------ test scroll to bottom -----------------------------------
    'Task seq 1 ' .. sidebar_height,
    function()
      -- since last command is newly executed, its output should scroll to bottom
      vim.api.nvim_set_current_win(task_panel.task_output_winid)
      abort_tests_if_not(vim.fn.line('w0') ~= 1)
      -- go back to beginning window to prepare for the next test
      vim.api.nvim_set_current_win(winid)
    end,
    'Task seq 1 ' .. sidebar_height,
    function()
      -- when running command outside of task panel, the output should also scroll
      -- to bottom
      vim.api.nvim_set_current_win(task_panel.task_output_winid)
      abort_tests_if_not(vim.fn.line('w0') ~= 1)
      vim.api.nvim_set_current_win(task_panel.sidebar_winid)
      vim.api.nvim_win_close(task_panel.sidebar_winid, false)
    end,
    'Task seq 1 ' .. sidebar_height,
    'ListTask',
    function()
      -- when running command with task panel closed and then open it, the output
      -- should also scroll to bottom
      vim.api.nvim_set_current_win(task_panel.task_output_winid)
      abort_tests_if_not(vim.fn.line('w0') ~= 1)
      vim.api.nvim_set_current_win(task_panel.sidebar_winid)
    end,
    [[ call feedkeys("\<cr>") ]],
    function()
      -- when restarting command, the output should also scroll to bottom
      vim.api.nvim_set_current_win(task_panel.task_output_winid)
      abort_tests_if_not(vim.fn.line('w0') ~= 1)
      vim.api.nvim_set_current_win(task_panel.sidebar_winid)
    end,
    ------------------ end test ------------------------------------------------

    ------------------ test restarting task ------------------------------------
    '+2',
    'Task python --version',
    'Task tree',
    'ListTask',
    'normal! G',
    [[ call feedkeys("\<cr>") ]],
    function()
      -- if <cr> does restart the first task, then it should be running now
      abort_tests_if_not(task_panel.focused_task_range.task_id == 1)
      local task = all_tasks[task_panel.focused_task_range.task_id]
      local header = vim.api.nvim_buf_get_lines(
        task_panel.sidebar_bufnr,
        task_panel.focused_task_range.start_line - 1,
        task_panel.focused_task_range.end_line,
        true
      )
      abort_tests_if_not(task.cmd:match('^sleep'))
      abort_tests_if_not(task.status == 'RUNNING')
      abort_tests_if_not(header[1]:match('^RUNNING: sleep'))
    end,
    ------------------ end test ------------------------------------------------

    ------------------ test starting new task ----------------------------------
    '+5',
    'Task make',
    function()
      -- newly created task should be automatically focused and put in the front
      abort_tests_if_not(task_panel.focused_task_range.start_line == 1)
      abort_tests_if_not(
        all_tasks[task_panel.focused_task_range.task_id].cmd == 'make'
      )
    end,
    ------------------ end test ------------------------------------------------

    ------------------ test running tasks when panel is closed -----------------
    'Task cat longline',
    'Task brew update',
    'wincmd c',
    'Task ls',
    'Task tree',
    'ListTask',
    '+2',
    '+5',
    ------------------ end test ------------------------------------------------

    ------------------ test closing and reopen panel ---------------------------
    'normal! gg',
    'normal! 16G7|',
    'wincmd p',
    function()
      abort_tests_if_not(task_panel.sidebar_winid ~= nil)
      abort_tests_if_not(task_panel.task_output_winid ~= nil)
      vim.api.nvim_set_current_win(task_panel.task_output_winid)
    end,
    'wincmd c',
    function()
      -- both window should be closed
      abort_tests_if_not(task_panel.sidebar_winid == nil)
      abort_tests_if_not(task_panel.task_output_winid == nil)
      abort_tests_if_not(vim.api.nvim_get_current_win() == winid)
    end,
    'ListTask',
    function()
      abort_tests_if_not(
        vim.api.nvim_get_current_win() == task_panel.sidebar_winid
      )
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      -- cursor should not move after reopen
      abort_tests_if_not(row == 16 and col == 6)
    end,
    ------------------ end test ------------------------------------------------

    ------------------ test window view save and restore -----------------------
    'Task seq 1 200',
    function()
      vim.api.nvim_set_current_win(task_panel.task_output_winid)
      local line_cnt = vim.api.nvim_buf_line_count(0)
      -- cursor should stay at bottom now
      abort_tests_if_not(line_cnt == vim.api.nvim_win_get_cursor(0)[1])
      vim.cmd('normal! 120G3|')
      vim.cmd('normal! H')
    end,
    'wincmd c',
    'ListTask',
    function()
      vim.api.nvim_set_current_win(task_panel.task_output_winid)
      -- the top line should be line 115
      abort_tests_if_not(vim.fn.line('w0') == 115)
      -- cursor should stay at 115
      abort_tests_if_not(vim.api.nvim_win_get_cursor(0)[1] == 115)
    end,
    ------------------ end test ------------------------------------------------

    'tabclose',
  }

  timer:start(
    delay,
    delay,
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
