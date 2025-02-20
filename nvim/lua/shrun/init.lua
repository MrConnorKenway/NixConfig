local M = {}

---@alias shrun.TaskStatus
---| 'RUNNING'
---| 'CANCELED'
---| 'SUCCESS'
---| 'FAILED'

---@class shrun.Task
---@field id integer
---@field cmd string
---@field escaped_cmd string
---@field view vim.fn.winsaveview.ret
---@field status shrun.TaskStatus
---@field buf_id integer
---@field job_id integer
---@field output_tail string
---@field output_line_num integer?
---@field follow_term_output boolean
---@field elapsed_time integer
---@field timer uv.uv_timer_t?

---@class shrun.TaskRange
---@field start_line integer
---@field end_line integer
---@field task_id integer

---all registered tasks
---@type table<integer, shrun.Task>
local all_tasks = {}
local next_task_id = 1

---@class shrun.TaskPanel
---@field sidebar_bufnr integer
---map from task id to task range
---@field task_ranges table<integer, shrun.TaskRange> NOTE: do not use ipairs to iterate task_ranges
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

---@type integer
local empty_task_output_buf = -1

local original_winid = -1

-- TODO: make configurable
local sidebar_width = 48
local sidebar_height = 16
local separator_stem = '─'
local out_prefix = 'out: '
local default_highlights = {
  ShrunHighlightTaskRUNNING = 'Constant',
  ShrunHighlightTaskSUCCESS = 'DiagnosticOk',
  ShrunHighlightTaskFAILED = 'DiagnosticError',
  ShrunHighlightTaskFocus = 'CursorLine',
  ShrunHighlightTaskName = 'Title',
  ShrunHighlightTaskOutPrefix = 'Comment',
}
local timer_repeat_interval = 1000

--- Helper function that generate line content and highlight metadata of task
--- based on the row offset, which will be then used for sidebar rendering
---@param task shrun.Task
---@param row_offset integer zero-based indexing start row
local function render_task(task, row_offset)
  local lines = {} ---@type string[]
  ---@type {[1]: string, [2]: integer, [3]: integer, [4]: integer}[]
  ---       group name,  start row,    start col,    end col
  local highlights = {}
  local status_len = string.len(task.status)
  local cmd_offset = status_len + 2 -- 2 == len(': ')

  table.insert(lines, task.status .. ': ' .. task.escaped_cmd)
  table.insert(highlights, {
    'ShrunHighlightTask' .. task.status,
    row_offset + #lines,
    0,
    status_len,
  })
  table.insert(highlights, {
    'ShrunHighlightTaskName',
    row_offset + #lines,
    cmd_offset,
    cmd_offset + string.len(task.escaped_cmd),
  })

  -- TODO: make minimum interval configurable
  if task.elapsed_time > 3000 then
    local seconds = task.elapsed_time / 1000
    local minutes
    local hours

    if seconds < 60 then
      table.insert(lines, tostring(seconds) .. 's')
    elseif seconds < 3600 then
      minutes = math.floor(seconds / 60)
      seconds = seconds % 60
      table.insert(lines, string.format('%dm %ds', minutes, seconds))
    else
      hours = math.floor(seconds / 3600)
      minutes = math.floor(seconds / 60) % 60
      seconds = seconds % 60
      table.insert(lines, string.format('%dh %dm %ds', hours, minutes, seconds))
    end
  end

  -- Remove control characters and ANSI escape sequences using regex
  -- Reference: https://stackoverflow.com/questions/14693701
  local striped_str = task
    .output_tail
    :gsub('[\r\x07]', '')
    :gsub('\x1b[@-Z\\-_]', '') -- 7-bit C1 Fe (except CSI)
    :gsub('\x1b%[[0-?]*[ -/]*[@-~]', '') -- second char is '[', i.e., CSI
  table.insert(lines, out_prefix .. striped_str)

  task.output_line_num = row_offset + #lines
  table.insert(highlights, {
    'ShrunHighlightTaskOutPrefix',
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

  if task.follow_term_output then
    scroll_terminal_to_tail(task.buf_id)
  else
    vim.api.nvim_win_call(task_panel.task_output_winid, function()
      vim.fn.winrestview(task.view)
    end)
  end
end

--- Highlight current focused task in sidebar and switch task output panel
--- to display the output buffer of focused task
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

  vim.api.nvim_buf_set_extmark(
    task_panel.sidebar_bufnr,
    sidebar_focus_hl_ns,
    task_range.start_line - 1,
    0,
    {
      line_hl_group = 'ShrunHighlightTaskFocus',
      end_row = task_range.end_line - 1,
    }
  )

  if task_panel.task_output_winid and task_panel.focused_task_range then
    switch_task_out_panel(all_tasks[task_panel.focused_task_range.task_id])
  end
end

-- Currently only support one line extmark
local function apply_extmarks(extmarks)
  for _, extmark in ipairs(extmarks) do
    local group, row_start = unpack(extmark)
    vim.api.nvim_buf_set_extmark(
      task_panel.sidebar_bufnr,
      sidebar_hl_ns,
      row_start - 1,
      0,
      { hl_eol = true, hl_group = group, end_row = row_start }
    )
  end
end

local function redraw_panel(lines, highlights, start_line, end_line, extmarks)
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
    vim.hl.range(
      task_panel.sidebar_bufnr,
      sidebar_hl_ns,
      group,
      { row_start - 1, col_start },
      { row_start - 1, col_end }
    )
  end

  if extmarks then
    apply_extmarks(extmarks)
  end

  -- Since extmark highlight is bound to buffer, we should highlight focused
  -- task even if task panel is not opened
  highlight_focused()
end

--- add offset to every task range after start_line
---@param offset integer
---@param start_line integer
local function move_task_ranges(offset, start_line)
  for _, range in pairs(task_panel.task_ranges) do
    if range.start_line > start_line then
      local task = all_tasks[range.task_id]
      if task.output_line_num then
        task.output_line_num = task.output_line_num + offset
      end
      range.start_line = range.start_line + offset
      range.end_line = range.end_line + offset
    end
  end
end

--- Partially update the content of sidebar buffer (called "render") in the
--- range of `task`. Following tasks' ranges will be updated accordingly.
---@param task shrun.Task
local function partial_render_sidebar(task)
  local task_range = task_panel.task_ranges[task.id]
  local old_end_line = task_range.end_line

  local lines, highlights = render_task(task, task_range.start_line - 1)
  task_range.end_line = task_range.start_line + #lines - 1

  local offset = task_range.end_line - old_end_line
  if offset ~= 0 then
    move_task_ranges(offset, task_range.start_line)
  end

  redraw_panel(lines, highlights, task_range.start_line - 1, old_end_line)
end

---@generic K, V
---@param tbl table<K, V>
---@return (fun(): K, V)
local function desc_sorted_pairs(tbl)
  local keys = {}
  for k in pairs(tbl) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return a > b
  end)

  local idx = 0
  return function()
    idx = idx + 1
    if keys[idx] then
      return keys[idx], tbl[keys[idx]]
    end
  end
end

---caller should ensure that `task_panel` ~= nil
local function render_sidebar_from_scratch()
  local lines = {}
  local highlights = {}
  local extmarks = {}
  local separator = string.rep(separator_stem, vim.o.columns)

  task_panel.task_ranges = {}
  -- lua does not guarantee the order when iterating table, so we have to
  -- manually sort task id
  for task_id, task in desc_sorted_pairs(all_tasks) do
    local task_lines, task_highlights = render_task(task, #lines)
    task_panel.task_ranges[task_id] = {
      start_line = #lines + 1,
      end_line = #lines + #task_lines,
      task_id = task.id,
    }
    vim.list_extend(lines, task_lines)
    vim.list_extend(highlights, task_highlights)
    if task_id > 1 then
      table.insert(lines, separator)
      table.insert(extmarks, { 'FloatBorder', #lines, 0, -1 })
    end
  end

  redraw_panel(lines, highlights, 0, -1, extmarks)
end

---@param lnum integer
---@return shrun.TaskRange?
local function sidebar_get_task_range_from_line(lnum)
  for _, task_range in desc_sorted_pairs(task_panel.task_ranges) do
    if task_range.end_line >= lnum then
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

  if task_panel.focused_task_range == range then
    return
  end

  task_panel.focused_task_range = range
  highlight_focused()
end

local function save_original_winid()
  local prev_winnr = vim.fn.winnr('#')
  local prev_winid = vim.fn.win_getid(prev_winnr)
  if
    prev_winid ~= task_panel.task_output_winid
    and prev_winid ~= task_panel.sidebar_winid
  then
    original_winid = prev_winid
  end
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

  local autocmd_id = vim.api.nvim_create_autocmd('WinEnter', {
    pattern = tostring(winid),
    callback = save_original_winid,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(winid),
    once = true,
    callback = function()
      task_panel.task_output_winid = nil
      vim.api.nvim_del_autocmd(autocmd_id)
      vim.schedule(function()
        if task_panel.sidebar_winid then
          if vim.api.nvim_get_current_win() == task_panel.sidebar_winid then
            vim.cmd('q')
            pcall(vim.api.nvim_set_current_win, original_winid)
            original_winid = -1
          else
            vim.api.nvim_win_hide(task_panel.sidebar_winid)
          end
        end
      end)
    end,
  })
  return winid
end

local function get_terminal_size()
  local width
  local height

  if task_panel.task_output_winid then
    width = vim.api.nvim_win_get_width(task_panel.task_output_winid)
    height = vim.api.nvim_win_get_height(task_panel.task_output_winid)
  else
    width = vim.o.columns - sidebar_width
    height = sidebar_height
  end

  return width, height
end

---Currently when calling `vim.api.nvim_open_term`, neovim's libvterm will use
---the width of current window to render terminal output, thus we have to create
---a temporary window that has equal size with task output panel to mitigate such
---issue
---@param bufnr integer
---@param fn fun()
local function run_in_tmp_win(bufnr, fn)
  local start_winid = vim.api.nvim_get_current_win()
  local width, height = get_terminal_size()

  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = 'editor',
    width = width,
    height = height,
    row = 0,
    col = 0,
    noautocmd = true,
  })
  vim.api.nvim_set_current_win(winid)
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    vim.notify(vim.inspect(err), vim.log.levels.ERROR)
  end
  vim.api.nvim_win_close(winid, false)
  vim.api.nvim_set_current_win(start_winid)
end

---@param task shrun.Task
local function new_task_output_buffer(task)
  task.buf_id = vim.api.nvim_create_buf(false, true)

  vim.keymap.set('n', 'gf', function()
    local f = vim.fn.findfile(vim.fn.expand('<cfile>'), '**')
    if f == '' then
      Snacks.notify.warn('No file under cursor')
    else
      if vim.api.nvim_win_is_valid(original_winid) then
        vim.api.nvim_set_current_win(original_winid)
      else
        vim.api.nvim_win_hide(task_panel.task_output_winid)
      end

      vim.schedule(function()
        vim.cmd('e ' .. f)
      end)
    end
  end, { buffer = task.buf_id, desc = 'Open file under cursor' })

  vim.api.nvim_create_autocmd({ 'WinScrolled', 'CursorMoved' }, {
    buffer = task.buf_id,
    callback = function()
      if vim.api.nvim_get_current_buf() ~= task.buf_id then
        return
      end

      -- current buffer must be task's output buffer and current window must be
      -- task output window
      local row = vim.api.nvim_win_get_cursor(task_panel.task_output_winid)[1]
      -- if user moves cursor to non bottom, it is reasonable to assume that user
      -- wants to disable automatically scrolling and keeps the cursor fixed
      if row < vim.api.nvim_buf_line_count(task.buf_id) then
        task.follow_term_output = false
        task.view = vim.fn.winsaveview()
      else
        task.follow_term_output = true
      end
    end,
  })
end

---@param task shrun.Task
local function update_time_in_task_output(task)
  task.elapsed_time = task.elapsed_time + timer_repeat_interval
  partial_render_sidebar(task)
end

---@param task shrun.Task
local function start_task(task)
  new_task_output_buffer(task)
  task.status = 'RUNNING'
  task.output_tail = ''
  task.follow_term_output = true
  task.escaped_cmd = task.cmd:gsub('\n', ' 󰌑 '):gsub('\t', '')
  task.elapsed_time = 0
  task.timer = vim.uv.new_timer()

  -- 'sleep': wait 100ms before finishing job, giving neovim enough time to sync output
  local new_cmd = {
    vim.o.shell,
    '-c',
    string.format('set -e; %s; sleep 0.1', task.cmd),
  }

  local render_timer = vim.uv.new_timer()
  if not render_timer then
    error('Failed to create uv timer')
  end

  local timer_running = false
  local render_fn = vim.schedule_wrap(function()
    if task.output_line_num then
      partial_render_sidebar(task)
    end
    timer_running = false
  end)

  run_in_tmp_win(task.buf_id, function()
    task.job_id = vim.fn.jobstart(new_cmd, {
      term = true,
      on_stdout = function(_, out)
        if task.status == 'CANCELED' then
          return
        end
        for i = #out, 1, -1 do
          if out[i]:len() > 0 and out[i] ~= '\r' then
            task.output_tail = out[i]
            break
          end
        end
        if not timer_running then
          timer_running = true
          render_timer:start(0, 0, render_fn)
        end
      end,
      on_exit = function(_, exit_code, _)
        if vim.api.nvim_get_current_buf() == task.buf_id then
          vim.cmd('stopinsert')
        end
        if task.timer and not task.timer:is_closing() then
          task.timer:close()
        end
        if task.status == 'CANCELED' then
          return
        end
        if exit_code == 0 then
          task.status = 'SUCCESS'
          partial_render_sidebar(task)
          -- TODO: currently relies on Snacks.nvim's markdown support to change the
          -- style, not a perfect solution
          vim.notify(
            task.escaped_cmd .. ' `SUCCESS`',
            vim.log.levels.INFO,
            { timeout = 2000 }
          )
        else
          task.status = 'FAILED'
          partial_render_sidebar(task)
          -- TODO: currently relies on Snacks.nvim's markdown support to change the
          -- style, not a perfect solution
          vim.notify(
            task.escaped_cmd .. ' **FAILED**',
            vim.log.levels.ERROR,
            { timeout = 2000 }
          )
        end
      end,
    })
  end)

  if task.job_id <= 0 then
    error(string.format('Failed to start task "%s"', task.escaped_cmd))
    task.status = 'FAILED'
    return
  end

  if task.timer then
    task.timer:start(
      timer_repeat_interval,
      timer_repeat_interval,
      vim.schedule_wrap(function()
        if task.status ~= 'RUNNING' then
          task.timer:close()
          task.timer = nil
          return
        end
        update_time_in_task_output(task)
      end)
    )
  else
    vim.notify('Shrun failed to start uv.timer', vim.log.levels.ERROR)
  end

  vim.api.nvim_buf_set_name(
    task.buf_id,
    string.format('shrun://%d//%s', task.job_id, task.escaped_cmd)
  )
end

---@param task shrun.Task
local function restart_task(task)
  local old_buf = task.buf_id
  -- Delay buffer delete after new buffer is opened in task output window,
  -- otherwise the task output window will be instantly closed
  vim.schedule(function()
    vim.api.nvim_buf_delete(old_buf, {})
  end)
  start_task(task)
  partial_render_sidebar(task)
end

---@return shrun.Task
local function get_task_under_cursor()
  local range = task_panel.focused_task_range
  if not range then
    error('No task under cursor')
  end
  return all_tasks[range.task_id]
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

  vim.keymap.set('n', '<C-n>', function()
    local range = task_panel.focused_task_range
    if not range then
      return
    end

    if range.end_line == vim.api.nvim_buf_line_count(sidebar_bufnr) then
      return
    end

    local col = vim.api.nvim_win_get_cursor(task_panel.sidebar_winid)[2]
    vim.api.nvim_win_set_cursor(
      task_panel.sidebar_winid,
      -- FIXME: if the sperator takes more than one line in the future
      { range.end_line + 2, col }
    )
  end, { buffer = sidebar_bufnr, desc = 'Goto next task' })

  vim.keymap.set('n', '<C-p>', function()
    local range = task_panel.focused_task_range
    if not range then
      return
    end

    if range.start_line == 1 then
      return
    end

    local col = vim.api.nvim_win_get_cursor(task_panel.sidebar_winid)[2]
    -- In sidebar, task with larger ID comes closer to the top, so the task
    -- ranges are actually sorted in ascending order
    for _, prev_range in desc_sorted_pairs(task_panel.task_ranges) do
      -- FIXME: if the sperator takes more than one line in the future
      if prev_range.end_line + 2 == range.start_line then
        vim.api.nvim_win_set_cursor(
          task_panel.sidebar_winid,
          { prev_range.start_line, col }
        )
        return
      end
    end
  end, { buffer = sidebar_bufnr, desc = 'Goto previous task' })

  vim.keymap.set('n', '<cr>', function()
    local task = get_task_under_cursor()
    if task.status ~= 'RUNNING' then
      restart_task(task)
    end
  end, { buffer = sidebar_bufnr, desc = 'Restart task under cursor' })

  vim.keymap.set('n', 'i', function()
    local task = get_task_under_cursor()
    vim.api.nvim_set_current_win(task_panel.task_output_winid)
    if task.status == 'RUNNING' then
      vim.cmd('startinsert')
    end
  end, {
    buffer = sidebar_bufnr,
    desc = 'Switch to task under cursor',
  })

  vim.keymap.set('n', 'x', function()
    local range = task_panel.focused_task_range
    if not range then
      return
    end
    task_panel.focused_task_range = nil

    local task = all_tasks[range.task_id]

    if task.status == 'RUNNING' then
      task.status = 'CANCELED'
      vim.fn.jobstop(task.job_id)
      vim.fn.chanclose(task.job_id)
    end

    all_tasks[task.id] = nil
    task_panel.task_ranges[task.id] = nil

    local nr_tasks = 0
    for _ in pairs(all_tasks) do
      nr_tasks = nr_tasks + 1
    end

    vim.bo[task_panel.sidebar_bufnr].modifiable = true
    if nr_tasks == 0 then
      vim.api.nvim_buf_set_lines(task_panel.sidebar_bufnr, 0, -1, true, {})
      vim.api.nvim_buf_clear_namespace(
        task_panel.sidebar_bufnr,
        sidebar_focus_hl_ns,
        0,
        -1
      )
    else
      if range.start_line == 1 then
        vim.api.nvim_buf_set_lines(
          task_panel.sidebar_bufnr,
          0,
          range.end_line + 1,
          true,
          {}
        )
      else
        vim.api.nvim_buf_set_lines(
          task_panel.sidebar_bufnr,
          range.start_line - 2,
          range.end_line,
          false,
          {}
        )
      end

      -- offset = -(range.end_line - range.start_line + 2)
      --        = range.start_line - 2 - range.end_line
      move_task_ranges(range.start_line - 2 - range.end_line, range.start_line)
    end
    vim.bo[task_panel.sidebar_bufnr].modifiable = false
    vim.bo[task_panel.sidebar_bufnr].modified = false

    vim.schedule(function()
      vim.api.nvim_buf_delete(task.buf_id, { force = true })
    end)
  end, { buffer = sidebar_bufnr, desc = 'Delete task under cursor' })

  vim.api.nvim_create_autocmd('BufEnter', {
    buffer = sidebar_bufnr,
    callback = save_original_winid,
  })

  vim.api.nvim_create_autocmd('BufHidden', {
    buffer = sidebar_bufnr,
    callback = function()
      task_panel.sidebar_cursor =
        vim.api.nvim_win_get_cursor(task_panel.sidebar_winid)
      task_panel.sidebar_winid = nil
      vim.schedule(function()
        if task_panel.task_output_winid then
          if vim.api.nvim_get_current_win() == task_panel.task_output_winid then
            vim.cmd('q')
            pcall(vim.api.nvim_set_current_win, original_winid)
            original_winid = -1
          else
            vim.api.nvim_win_hide(task_panel.task_output_winid)
          end
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
  if not vim.api.nvim_buf_is_valid(task_panel.sidebar_bufnr) then
    task_panel.sidebar_bufnr = new_sidebar_buffer()
  end

  if
    next(all_tasks)
    and vim.api.nvim_buf_line_count(task_panel.sidebar_bufnr) <= 1
  then
    render_sidebar_from_scratch()
  end

  if task_panel.sidebar_winid then
    return
  end
  if not vim.api.nvim_buf_is_valid(empty_task_output_buf) then
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
    if not vim.api.nvim_buf_is_valid(task.buf_id) then
      new_task_output_buffer(task)
    end
    task_panel.task_output_winid = new_task_output_window(task.buf_id)
    if task.follow_term_output then
      scroll_terminal_to_tail(task.buf_id)
    else
      vim.api.nvim_win_call(task_panel.task_output_winid, function()
        vim.fn.winrestview(task.view)
      end)
    end
  else
    task_panel.task_output_winid = new_task_output_window(empty_task_output_buf)
  end
end

M.hide_panel = function()
  if task_panel.sidebar_winid then
    vim.api.nvim_win_hide(task_panel.sidebar_winid)
  end
end

M.toggle_panel = function()
  if task_panel.sidebar_winid then
    vim.api.nvim_win_hide(task_panel.sidebar_winid)
    return
  end

  if package.loaded.snacks.terminal then
    for _, term in ipairs(require('snacks.terminal').list()) do
      if not term.closed then
        term:hide()
      end
    end
  end

  M.display_panel()
end

M.nr_tasks_by_status = function()
  local nr_tasks_by_status = {
    ['CANCELED'] = 0,
    ['FAILED'] = 0,
    ['SUCCESS'] = 0,
    ['RUNNING'] = 0,
  }
  for _, task in pairs(all_tasks) do
    nr_tasks_by_status[task.status] = nr_tasks_by_status[task.status] + 1
  end

  return nr_tasks_by_status
end

local function setup_highlights()
  for hl, link in pairs(default_highlights) do
    vim.api.nvim_set_hl(0, hl, { link = link })
  end
end

local function init_task_from_cmd(cmd)
  ---@type shrun.Task | {}
  local task = {
    id = next_task_id,
    cmd = cmd.args or cmd,
  }
  next_task_id = next_task_id + 1

  if not vim.api.nvim_buf_is_valid(task_panel.sidebar_bufnr) then
    task_panel.sidebar_bufnr = new_sidebar_buffer()
    render_sidebar_from_scratch()
  end

  start_task(task)
  all_tasks[task.id] = task

  local extmarks = {}
  local lines, highlights = render_task(task, 0)
  local task_range = { start_line = 1, end_line = #lines, task_id = task.id }
  local empty = next(task_panel.task_ranges) == nil

  if not empty then
    local separator = string.rep(separator_stem, vim.o.columns)
    table.insert(lines, separator)
    table.insert(extmarks, { 'FloatBorder', #lines })
    move_task_ranges(#lines, 0)
  end
  task_panel.task_ranges[task.id] = task_range

  vim.bo[task_panel.sidebar_bufnr].modifiable = true
  if empty then
    vim.api.nvim_buf_set_lines(task_panel.sidebar_bufnr, 0, -1, true, lines)
  else
    vim.api.nvim_buf_set_lines(task_panel.sidebar_bufnr, 0, 0, true, lines)
  end
  vim.bo[task_panel.sidebar_bufnr].modifiable = false
  vim.bo[task_panel.sidebar_bufnr].modified = false

  for _, hl in ipairs(highlights) do
    local group, lnum, col_start, col_end = unpack(hl)
    vim.hl.range(
      task_panel.sidebar_bufnr,
      sidebar_hl_ns,
      group,
      { lnum - 1, col_start },
      { lnum - 1, col_end }
    )
  end

  apply_extmarks(extmarks)

  if task_panel.sidebar_winid then
    vim.api.nvim_win_set_cursor(task_panel.sidebar_winid, { 1, 0 })
    task_panel.focused_task_range = task_range
    highlight_focused()
  else
    -- task list panel is not opened, record the cursor here and defer the
    -- cursor update after `ListTask`
    task_panel.sidebar_cursor = { 1, 0 }
  end
end

---Find task by cmd and reuse it instead of creating new task to execute cmd
---@param cmd string
M.restart_task_from_cmd = function(cmd)
  for _, task in pairs(all_tasks) do
    if task.cmd == cmd then
      if task.status ~= 'RUNNING' then
        restart_task(task)
      end
      return
    end
  end

  -- No reusable task
  init_task_from_cmd(cmd)
end

local shell_buf
local shell_job
local shell_win

M.setup = function()
  task_panel = {
    sidebar_bufnr = -1,
    task_ranges = {},
  }

  setup_highlights()

  vim.api.nvim_create_autocmd('ColorScheme', {
    callback = setup_highlights,
  })

  vim.keymap.set('n', 'gu', function()
    M.restart_task_from_cmd('git push')
  end, { desc = 'Git push' })

  vim.keymap.set('n', '``', function()
    local shell = vim.o.shell:gsub('(.*)/', '')
    local shell_args
    local shell_envs = {
      TERM_PROGRAM = 'neovim',
    }
    local home_dir = vim.uv.os_homedir()
    -- FIXME: hard coded config
    local width = 80
    local height = 2
    local max_height = 20

    if shell_win and vim.api.nvim_win_is_valid(shell_win) then
      vim.cmd('startinsert')
      return
    end

    -- Currently only support zsh with p10k prompt
    if shell == 'zsh' and vim.fn.environ()['PATH']:find('powerlevel10k') then
      shell_args = { 'zsh' }
      shell_envs = vim.tbl_extend('force', shell_envs, {
        ITERM_SHELL_INTEGRATION_INSTALLED = 'Yes', -- enable p10k OSC 133 support
        USER_ZDOTDIR = home_dir,
        ZDOTDIR = string.format('%s/.config/nvim/shell_integration', home_dir),
        FZF_DEFAULT_OPTS = '--layout=reverse --height=100%',
      })
    else
      error(string.format('Unsupported shell "%s"', shell))
    end

    if not shell_buf then
      shell_buf = vim.api.nvim_create_buf(false, true)

      vim.api.nvim_create_autocmd('BufEnter', {
        buffer = shell_buf,
        callback = function()
          vim.cmd('startinsert')
        end,
      })

      vim.api.nvim_create_autocmd('TermRequest', {
        buffer = shell_buf,
        callback = function(args)
          local request = args.data
          local found = request:find('\x1b]633')
          if found then
            local cmd = request:match('\x1b]633;E;(.*)', found)
            if cmd then
              -- Now we get the actual command by parsing OSC 633;E
              pcall(vim.api.nvim_win_hide, shell_win)
              vim.cmd('stopinsert')
              if task_panel.sidebar_winid then
                vim.api.nvim_set_current_win(task_panel.sidebar_winid)
              end
              -- Revert escape
              cmd =
                cmd:gsub('\\x3b', ';'):gsub('\\x0a', '\n'):gsub('\\\\', '\\')
              vim.schedule(function()
                M.display_panel()
                init_task_from_cmd(cmd)
              end)
              return
            end
          end

          found = request:find('\x1b]133;B')
          if found and vim.api.nvim_win_is_valid(shell_win) then
            -- Resize to original height if we meet prompt end, i.e., OSC 133;B
            vim.cmd('resize ' .. height)
          end
        end,
      })
      vim.keymap.set('t', '<C-r>', function()
        vim.cmd('resize ' .. max_height)
        vim.api.nvim_chan_send(shell_job, '\x12')
      end, { buffer = shell_buf })

      vim.keymap.set('t', '<C-d>', function()
        vim.api.nvim_win_hide(shell_win)
      end, { buffer = shell_buf, desc = 'Hide shrun launcher' })
    end

    shell_win = vim.api.nvim_open_win(shell_buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = math.floor((vim.o.lines - max_height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      style = 'minimal',
      border = 'rounded',
    })
    vim.wo[shell_win].winhighlight = 'NormalFloat:Normal'

    if not shell_job then
      shell_job = vim.fn.jobstart(shell_args, {
        term = true,
        env = shell_envs,
        on_exit = function()
          shell_buf = nil
          shell_job = nil
        end,
      })
    end
  end, { desc = 'Open shrun launcher' })

  vim.api.nvim_create_user_command('Task', init_task_from_cmd, {
    complete = vim.fn.has('nvim-0.11') == 0 and 'shellcmd' or 'shellcmdline',
    nargs = '+',
    desc = 'Run task',
  })

  vim.api.nvim_create_user_command('ListTask', M.display_panel, {
    nargs = 0,
    desc = 'Show sidebar',
  })

  vim.keymap.set(
    { 'n', 'i', 't' },
    '<D-r>',
    M.toggle_panel,
    { desc = 'Toggle shrun task panel' }
  )
  vim.keymap.set(
    { 'n', 'i', 't' },
    '<M-r>',
    M.toggle_panel,
    { desc = 'Toggle shrun task panel' }
  )
end

---for development test purpose only
M.test = function()
  local timer = vim.uv.new_timer()
  local delay = 100
  local winid
  ---@type vim.fn.winsaveview.ret
  local saved_winview

  if not timer then
    return
  end

  local abort_tests_if_not = function(assertion)
    if not assertion then
      vim.uv.timer_stop(timer)
      vim.uv.close(timer)
      error('assertion failed', 2)
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
      saved_winview = vim.fn.winsaveview()
    end,
    'wincmd c',
    'ListTask',
    function()
      vim.api.nvim_set_current_win(task_panel.task_output_winid)
      local current_winview = vim.fn.winsaveview()
      for k, v in pairs(saved_winview) do
        abort_tests_if_not(current_winview[k] == v)
      end
    end,
    ------------------ end test ------------------------------------------------

    ------------------ test delete task ----------------------------------------
    'wincmd c',
    'ListTask',
    'Task sleep 10 && echo done',
    'normal x',
    'normal! G',
    'normal x',
    'wincmd c',
    'Task tree',
    'ListTask',
    'Task seq 1 20',
    'normal! M',
    [[ call feedkeys("\<cr>") ]],
    'normal! H',
    'normal x',
    [[ call feedkeys("\<cr>") ]],
    'normal! L',
    'normal x',
    [[ call feedkeys("\<cr>") ]],
    ------------------ end test ------------------------------------------------

    ------------------ test highlight focus for background tasks ---------------
    'ListTask',
    'Task sleep 10',
    'wincmd c',
    function()
      vim.api.nvim_chan_send(all_tasks[next_task_id - 1].job_id, 'data\ndata')
    end,
    'ListTask',
    function()
      local extmarks = vim.api.nvim_buf_get_extmarks(
        task_panel.sidebar_bufnr,
        sidebar_focus_hl_ns,
        0,
        -1,
        { details = true }
      )

      -- focused task should be on the top
      abort_tests_if_not(task_panel.focused_task_range.start_line == 1)
      abort_tests_if_not(#extmarks == 1)
      abort_tests_if_not(
        extmarks[1][2] == task_panel.focused_task_range.start_line - 1
      )
      abort_tests_if_not(
        extmarks[1][4].end_row == task_panel.focused_task_range.end_line - 1
      )
    end,
    'normal x',
    ------------------ end test ------------------------------------------------

    'tabclose',
  }

  local function sanity_check()
    local nr_tasks = 0
    local nr_ranges = 0
    local prev_end_line

    for _ in pairs(all_tasks) do
      nr_tasks = nr_tasks + 1
    end

    for _, r in desc_sorted_pairs(task_panel.task_ranges) do
      nr_ranges = nr_ranges + 1
      if prev_end_line then
        -- currently there is only one seperator line between two tasks
        abort_tests_if_not(prev_end_line + 2 == r.start_line)
      end
      prev_end_line = r.end_line
      abort_tests_if_not(all_tasks[r.task_id].id == r.task_id)
    end

    abort_tests_if_not(nr_tasks == nr_ranges)
    if prev_end_line then
      abort_tests_if_not(
        prev_end_line == vim.api.nvim_buf_line_count(task_panel.sidebar_bufnr)
      )
    else
      abort_tests_if_not(
        task_panel.sidebar_bufnr == -1
          or vim.api.nvim_buf_line_count(task_panel.sidebar_bufnr) == 1
      )
    end
  end

  local function cleanup()
    idx = 0

    ---@type (string|function)[]
    local cleanup_commands = { 'ListTask' }
    for _ in pairs(all_tasks) do
      cleanup_commands[#cleanup_commands + 1] = function()
        local nr_lines = vim.api.nvim_buf_line_count(task_panel.sidebar_bufnr)
        local seed = math.random()
        local target_line = math.floor((nr_lines - 1) * seed + 0.5) + 1
        vim.cmd(string.format('normal! %dG', target_line))
      end
      cleanup_commands[#cleanup_commands + 1] = 'normal x'
    end
    cleanup_commands[#cleanup_commands + 1] = 'wincmd q'

    vim.notify(tostring(#cleanup_commands), vim.log.levels.TRACE)

    timer:start(
      delay,
      delay,
      vim.schedule_wrap(function()
        idx = idx + 1
        if idx > #cleanup_commands then
          abort_tests_if_not(next(all_tasks) == nil)
          abort_tests_if_not(next(task_panel.task_ranges) == nil)

          vim.uv.timer_stop(timer)
          vim.uv.close(timer)

          next_task_id = 1
          vim.notify(
            'All tests passed',
            vim.log.levels.INFO,
            { timeout = 5000 }
          )
          return
        end

        if type(cleanup_commands[idx]) == 'string' then
          vim.cmd(cleanup_commands[idx])
        else
          cleanup_commands[idx]()
        end

        sanity_check()

        if vim.fn.empty(vim.v.errmsg) == 0 then
          vim.uv.timer_stop(timer)
          vim.uv.close(timer)
          return
        end
      end)
    )
  end

  timer:start(
    delay,
    delay,
    vim.schedule_wrap(function()
      idx = idx + 1
      if idx > #commands then
        vim.uv.timer_stop(timer)

        cleanup()
        return
      end

      if type(commands[idx]) == 'string' then
        vim.cmd(commands[idx])
      else
        commands[idx]()
      end

      sanity_check()

      if vim.fn.empty(vim.v.errmsg) == 0 then
        vim.uv.timer_stop(timer)
        vim.uv.close(timer)
        return
      end
    end)
  )
end

return M
