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
---@field focused_task_id integer
---@field tasklist_winid integer
---@field taskout_winid integer

---@class Sidebar
local sidebar

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
  local separator = string.rep('─', vim.o.columns)

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

local function sidebar_on_cursor_move(bufnr)
  local winid
  if vim.api.nvim_get_current_buf() == bufnr then
    winid = vim.api.nvim_get_current_win()
  else
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(winid)[1]
  ---@type Task
  local task

  -- get task from line
  for _, v in ipairs(sidebar.task_lines) do
    local end_lnum = v[1]
    if end_lnum >= lnum then
      task = v[2]
      if task.id == sidebar.focused_task_id then
        return
      end
      break
    end
  end

  if not task then
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
  vim.api.nvim_win_set_buf(sidebar.taskout_winid, task.buf_id)

  highlight_focused()
end

local function new_sidebar()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local task_lines = {}

  vim.api.nvim_buf_set_name(bufnr, 'TaskList')

  vim.bo[bufnr].filetype = 'tasklist'
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].bufhidden = 'hide'
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false

  vim.api.nvim_create_autocmd('BufHidden', {
    buffer = bufnr,
    callback = function()
      if vim.api.nvim_win_is_valid(sidebar.taskout_winid) then
        vim.api.nvim_win_close(sidebar.taskout_winid, false)
      end
    end
  })

  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = bufnr,
    nested = false, -- TODO: do we need nested?
    callback = function()
      sidebar_on_cursor_move(bufnr)
    end
  })

  vim.api.nvim_create_autocmd('User', {
    pattern = 'TaskListUpdate',
    callback = function()
      render_sidebar()
    end
  })

  return {
    bufnr = bufnr,
    task_lines = task_lines
  }
end

M.setup = function()
  vim.api.nvim_create_user_command('Task',
    function(cmd)
      ---@class Task
      local task = {}
      task.id = task_nr
      task_nr = task_nr + 1
      task.cmd = cmd.args
      task.buf_id = vim.api.nvim_create_buf(false, true)

      task.term_id = vim.api.nvim_open_term(task.buf_id, {
        on_input = function(_, _, _, data)
          vim.api.nvim_chan_send(task.job_id, data)
        end
      })
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
      vim.cmd [[botright split | enew]]
      sidebar.taskout_winid = vim.api.nvim_get_current_win()
      vim.cmd [[vsplit]]
      local tasklist_winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_height(tasklist_winid, 12)
      vim.api.nvim_win_set_width(tasklist_winid, 32)
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
    end,
    {
      nargs = 0,
      desc = 'Show task list'
    })
end

return M
