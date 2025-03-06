---@alias shrun.TaskStatus
---| 'IDLE'
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
local M = setmetatable({}, nil)
M.__index = M
M.meta = {
  desc = 'Shrun task',
}

local out_prefix = 'out: '

local function strip_escape_sequence(str)
  -- Remove control characters and ANSI escape sequences using regex
  -- Reference: https://stackoverflow.com/questions/14693701
  local striped_str, _ = str
    :gsub('[\r\x07]', '')
    :gsub('\x1b[@-Z\\-_]', '') -- 7-bit C1 Fe (except CSI)
    :gsub('\x1b%[[0-?]*[ -/]*[@-~]', '') -- second char is '[', i.e., CSI
  return striped_str
end

function M:update_output_tail(sidebar_bufnr)
  vim.bo[sidebar_bufnr].modifiable = true
  vim.api.nvim_buf_set_text(
    sidebar_bufnr,
    self.output_line_num - 1,
    out_prefix:len(),
    self.output_line_num - 1,
    -1,
    { strip_escape_sequence(self.output_tail) }
  )
  vim.bo[sidebar_bufnr].modifiable = false
  vim.bo[sidebar_bufnr].modified = false
end

--- Helper function that generate line content and highlight metadata of task
--- based on the row offset, which will be then used for sidebar rendering
---@param row_offset integer zero-based indexing start row
function M:render(row_offset)
  local lines = {} ---@type string[]
  ---@type {[1]: string, [2]: integer, [3]: integer, [4]: integer}[]
  ---       group name,  start row,    start col,    end col
  local highlights = {}
  local status_len = string.len(self.status)
  local cmd_offset = status_len + 2 -- 2 == len(': ')

  table.insert(lines, self.status .. ': ' .. self.escaped_cmd)
  table.insert(highlights, {
    'ShrunHighlightTask' .. self.status,
    row_offset + #lines,
    0,
    status_len,
  })

  local ok, parser =
    pcall(vim.treesitter.get_string_parser, self.escaped_cmd, 'bash')
  if ok and parser then
    parser:parse(true)
    parser:for_each_tree(function(tstree, _)
      if not tstree then
        return
      end
      local query = vim.treesitter.query.get('bash', 'highlights')
      if not query then
        return
      end

      for capture, node, metadata in
        query:iter_captures(tstree:root(), self.escaped_cmd)
      do
        ---@type string
        local name = query.captures[capture]
        local range = { node:range() } ---@type number[]
        local multi = range[1] ~= range[3]
        local text = multi
            and vim.split(
              vim.treesitter.get_node_text(
                node,
                self.escaped_cmd,
                metadata[capture]
              ),
              '\n',
              { plain = true }
            )
          or {}
        for row = range[1] + 1, range[3] + 1 do
          local first, last = row == range[1] + 1, row == range[3] + 1
          local end_col = last and range[4] or #(text[row - range[1]] or '')
          end_col = multi and first and end_col + range[2] or end_col
          table.insert(highlights, {
            '@' .. name .. '.bash',
            row_offset + #lines,
            cmd_offset + (first and range[2] or 0),
            cmd_offset + end_col,
          })
        end
      end
    end)
  else
    -- Fallback to default highlight
    table.insert(highlights, {
      'ShrunHighlightTaskName',
      row_offset + #lines,
      cmd_offset,
      cmd_offset + string.len(self.escaped_cmd),
    })
  end

  -- TODO: make minimum interval configurable
  if self.elapsed_time > 3000 then
    local seconds = self.elapsed_time / 1000
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

  table.insert(lines, out_prefix .. strip_escape_sequence(self.output_tail))

  self.output_line_num = row_offset + #lines
  table.insert(highlights, {
    'ShrunHighlightTaskOutPrefix',
    row_offset + #lines,
    0,
    string.len(out_prefix),
  })

  return lines, highlights
end

function M:new_task_output_buffer(task_panel, original_winid)
  self.buf_id = vim.api.nvim_create_buf(false, true)

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
  end, { buffer = self.buf_id, desc = 'Open file under cursor' })

  vim.api.nvim_create_autocmd({ 'WinScrolled', 'CursorMoved' }, {
    buffer = self.buf_id,
    callback = function()
      if vim.api.nvim_get_current_buf() ~= self.buf_id then
        return
      end

      -- current buffer must be task's output buffer and current window must be
      -- task output window
      local row = vim.api.nvim_win_get_cursor(task_panel.task_output_winid)[1]
      -- if user moves cursor to non bottom, it is reasonable to assume that user
      -- wants to disable automatically scrolling and keeps the cursor fixed
      if row < vim.api.nvim_buf_line_count(self.buf_id) then
        self.follow_term_output = false
        self.view = vim.fn.winsaveview()
      else
        self.follow_term_output = true
      end
    end,
  })
end

local function escape_cmd_str(cmd)
  return cmd:gsub('\n', ' 󰌑 '):gsub('\t', '')
end

---@param id integer
---@param cmd string
---@return shrun.Task
function M.new(id, cmd)
  ---@type shrun.Task
  local self = setmetatable({
    id = id,
    cmd = cmd,
    escaped_cmd = escape_cmd_str(cmd),
    status = 'IDLE',
    buf_id = -1,
    job_id = -1,
    output_tail = '',
    follow_term_output = true,
    elapsed_time = 0,
  }, M)
  return self
end

return M
