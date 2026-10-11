vim.opt.rtp:append(vim.fn.getcwd())
vim.opt.swapfile = false

local api = vim.api
local fn = vim.fn
---@type any
local test_lsp = vim.lsp

---@class BeaconTestRange: BeaconLspRange
---@field start { line: integer, character: integer }
---@field ["end"] { line: integer, character: integer }

---@class BeaconTestHighlight: BeaconDocumentHighlight
---@field range BeaconTestRange
---@field kind integer

---@class BeaconTestProgress
---@field pending table<any, any>

---@class BeaconTestClient
---@field id integer
---@field name? string
---@field offset_encoding string
---@field attached_buffers table<integer, boolean>
---@field progress BeaconTestProgress
---@field supports_method fun(self: BeaconTestClient, method: string, bufnr?: integer): boolean

---@class BeaconTestRequestResult
---@field result? BeaconTestHighlight[]
---@field error? { code: integer, message: string }

---@alias BeaconTestResponseCallback fun(results: table<integer, BeaconTestRequestResult>)

local original_lsp = {
  get_clients = test_lsp.get_clients,
  get_client_by_id = test_lsp.get_client_by_id,
  buf_request_all = test_lsp.buf_request_all,
  config = test_lsp.config,
  enabled_configs = test_lsp._enabled_configs,
}

---@class BeaconTestState
---@field clients table<integer, BeaconTestClient>
---@field request_handler fun(bufnr: integer, method: string, params: any, callback: BeaconTestResponseCallback): fun()
local lsp_state = {
  clients = {},
  request_handler = function(_, _, _, callback)
    callback {}
    return function() end
  end,
}

test_lsp.config = {}
test_lsp._enabled_configs = {}

test_lsp.get_clients = function(opts)
  opts = opts or {}
  ---@type BeaconTestClient[]
  local clients = {}

  for _, client in pairs(lsp_state.clients) do
    if not opts.bufnr or client.attached_buffers[opts.bufnr] then
      if not opts.method or client:supports_method(opts.method, opts.bufnr) then
        clients[#clients + 1] = client
      end
    end
  end

  table.sort(clients, function(a, b)
    return a.id < b.id
  end)

  return clients
end

test_lsp.get_client_by_id = function(id)
  return lsp_state.clients[id]
end

test_lsp.buf_request_all = function(bufnr, method, params, callback)
  return lsp_state.request_handler(bufnr, method, params, callback)
end

local beacon = dofile(vim.fs.joinpath(vim.fn.getcwd(), 'init.lua'))
local namespace = api.nvim_get_namespaces().beacon

---@param cond boolean
---@param message string
local function expect(cond, message)
  if not cond then
    error(message, 2)
  end
end

---@param actual any
---@param expected any
---@param message string
local function expect_eq(actual, expected, message)
  if actual ~= expected then
    error(
      string.format(
        '%s (expected %s, got %s)',
        message,
        vim.inspect(expected),
        vim.inspect(actual)
      ),
      2
    )
  end
end

---@param ranges integer[][]
---@return BeaconTestHighlight[]
local function document_highlights(ranges)
  ---@type BeaconTestHighlight[]
  local result = {}

  for _, range in ipairs(ranges) do
    result[#result + 1] = {
      range = {
        start = { line = range[1], character = range[2] },
        ['end'] = { line = range[3], character = range[4] },
      },
      kind = range[5] or 1,
    }
  end

  return result
end

---@param timeout integer
local function spin(timeout)
  vim.wait(timeout, function()
    return false
  end, 10)
end

---@param keys string
local function input(keys)
  api.nvim_feedkeys(
    api.nvim_replace_termcodes(keys, true, false, true),
    'xt',
    false
  )
end

---@param id integer
---@param attached_buffers table<integer, boolean>
---@param supports_highlight boolean
---@return BeaconTestClient
local function new_client(id, attached_buffers, supports_highlight)
  ---@type BeaconTestClient
  local client = {
    id = id,
    offset_encoding = 'utf-16',
    attached_buffers = attached_buffers,
    progress = { pending = {} },
    supports_method = function()
      return false
    end,
  }

  function client:supports_method(method, bufnr)
    return supports_highlight
      and method == 'textDocument/documentHighlight'
      and (not bufnr or self.attached_buffers[bufnr])
  end

  return client
end

---@param clients BeaconTestClient[]
local function set_clients(clients)
  lsp_state.clients = {}
  for _, client in ipairs(clients) do
    lsp_state.clients[client.id] = client
  end
end

local function reset_editor()
  pcall(api.nvim_del_augroup_by_name, 'Beacon')
  vim.cmd('silent! %bwipeout!')
  vim.cmd('enew!')
  fn.clearmatches()

  set_clients {}
  test_lsp.config = {}
  test_lsp._enabled_configs = {}
  lsp_state.request_handler = function(_, _, _, callback)
    callback {}
    return function() end
  end
end

---@param lines string[]
---@param filetype string
---@return integer
local function new_buffer(lines, filetype)
  local buf = api.nvim_create_buf(true, false)
  api.nvim_set_current_buf(buf)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = ''
  vim.bo[buf].filetype = filetype
  api.nvim_exec_autocmds('FileType', { buffer = buf, modeline = false })
  api.nvim_win_set_cursor(0, { 1, 0 })
  return buf
end

local function trigger_cursor_moved()
  api.nvim_exec_autocmds('CursorMoved', { modeline = false })
end

---@param bufnr integer
---@return integer
local function extmark_count(bufnr)
  return #api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
end

---@param bufnr integer
---@param expected integer[][]
---@param message string
local function expect_highlight_ranges(bufnr, expected, message)
  ---@type integer[][]
  local actual = {}
  for _, mark in
    ipairs(
      api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
    )
  do
    actual[#actual + 1] = { mark[2], mark[3], mark[4].end_row, mark[4].end_col }
  end
  expect(
    vim.deep_equal(actual, expected),
    ('%s (expected %s, got %s)'):format(
      message,
      vim.inspect(expected),
      vim.inspect(actual)
    )
  )
end

local tests = {}

tests[#tests + 1] = {
  name = 'LSP highlights only render in normal mode',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    lsp_state.request_handler = function(_, _, _, callback)
      callback {
        [client.id] = {
          result = document_highlights {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          },
        },
      }
      return function() end
    end

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']m', prev = '[m' },
    }

    trigger_cursor_moved()
    spin(20)
    expect(extmark_count(buf) > 0, 'expected normal-mode LSP extmarks')

    input 'v'
    spin(20)
    expect_eq(fn.mode(1), 'v', 'expected visual mode')
    expect_eq(extmark_count(buf), 0, 'visual mode should clear LSP extmarks')

    input '<Esc>'
    spin(20)
    expect_eq(fn.mode(1), 'n', 'expected normal mode after visual')
    expect(
      extmark_count(buf) > 0,
      'returning to normal mode should restore LSP extmarks'
    )

    input 'gh'
    spin(20)
    expect(fn.mode(1):sub(1, 1) == 's', 'expected select mode')
    expect_eq(
      extmark_count(buf),
      0,
      'select mode should clear LSP extmarks'
    )

    input '<Esc>'
    spin(20)
    expect_eq(fn.mode(1), 'n', 'expected normal mode after select')
    expect(
      extmark_count(buf) > 0,
      'returning to normal mode should restore LSP extmarks after select'
    )
  end,
}

tests[#tests + 1] = {
  name = 'window switches clear LSP highlights from the old buffer',
  run = function()
    reset_editor()
    local buf_a = new_buffer({ 'foo foo' }, 'lua')
    local win_a = api.nvim_get_current_win()

    vim.cmd('vsplit')
    local win_b = api.nvim_get_current_win()
    new_buffer({ 'bar' }, 'lua')
    api.nvim_set_current_win(win_a)

    local client = new_client(1, { [buf_a] = true }, true)
    set_clients { client }

    lsp_state.request_handler = function(_, _, _, callback)
      callback {
        [client.id] = {
          result = document_highlights {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          },
        },
      }
      return function() end
    end

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']o', prev = '[o' },
    }

    trigger_cursor_moved()
    spin(20)
    expect(extmark_count(buf_a) > 0, 'expected initial LSP extmarks')

    api.nvim_set_current_win(win_b)
    spin(20)

    expect_eq(
      extmark_count(buf_a),
      0,
      'switching windows should clear the old buffer LSP extmarks'
    )
  end,
}

tests[#tests + 1] = {
  name = 'same-buffer window switches keep active LSP highlights',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local win_a = api.nvim_get_current_win()

    vim.cmd('vsplit')
    local win_b = api.nvim_get_current_win()
    api.nvim_set_current_win(win_a)

    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    lsp_state.request_handler = function(_, _, _, callback)
      callback {
        [client.id] = {
          result = document_highlights {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          },
        },
      }
      return function() end
    end

    beacon.setup {
      delay_ms = 60,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']u', prev = '[u' },
    }

    trigger_cursor_moved()
    spin(90)
    expect(extmark_count(buf) > 0, 'expected initial LSP extmarks')

    api.nvim_set_current_win(win_b)
    spin(20)

    expect(
      extmark_count(buf) > 0,
      'same-buffer window switches should keep shared LSP extmarks active'
    )
  end,
}

tests[#tests + 1] = {
  name = 'same-buffer window switches keep same-target LSP requests in flight',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local win_a = api.nvim_get_current_win()

    vim.cmd('vsplit')
    local win_b = api.nvim_get_current_win()
    api.nvim_set_current_win(win_a)

    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    local request_count = 0
    local cancel_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      local timer = assert(vim.uv.new_timer(), 'expected request timer')
      local closed = false
      local completed = false

      local function close_timer(count_cancel)
        if closed then
          return
        end

        closed = true
        timer:stop()
        timer:close()
        if count_cancel and not completed then
          cancel_count = cancel_count + 1
        end
      end

      timer:start(
        80,
        0,
        vim.schedule_wrap(function()
          completed = true
          close_timer(false)
          callback {
            [client.id] = {
              result = document_highlights {
                { 0, 0, 0, 3 },
                { 0, 4, 0, 7 },
              },
            },
          }
        end)
      )

      return function()
        close_timer(true)
      end
    end

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']v', prev = '[v' },
    }

    trigger_cursor_moved()
    spin(20)
    expect_eq(request_count, 1, 'expected the initial LSP request to start')

    api.nvim_set_current_win(win_b)
    spin(20)

    expect_eq(
      cancel_count,
      0,
      'same-buffer window switches should keep the same-target request alive'
    )
    expect_eq(
      request_count,
      1,
      'same-buffer window switches should reuse the in-flight request'
    )

    spin(100)
    expect(
      extmark_count(buf) > 0,
      'same-target LSP responses should still render after the window switch'
    )
  end,
}

tests[#tests + 1] = {
  name = 'fallback highlights only render in normal mode',
  run = function()
    reset_editor()
    new_buffer({ 'foo foo' }, 'lua')

    beacon.setup {
      delay_ms = 60,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']m', prev = '[m' },
    }

    trigger_cursor_moved()
    spin(10)

    input 'v'
    spin(90)
    expect_eq(fn.mode(1), 'v', 'expected visual mode')
    expect_eq(
      #fn.getmatches(),
      0,
      'visual mode should keep delayed fallback matches cleared'
    )

    input '<Esc>'
    spin(10)
    expect_eq(fn.mode(1), 'n', 'expected normal mode after visual')
    expect_eq(
      #fn.getmatches(),
      0,
      'returning to normal mode should rearm the fallback delay'
    )

    spin(90)
    expect(
      #fn.getmatches() > 0,
      'normal mode should restore fallback matches after the delay'
    )

    input 'gh'
    spin(20)
    expect(fn.mode(1):sub(1, 1) == 's', 'expected select mode')
    expect_eq(
      #fn.getmatches(),
      0,
      'select mode should clear fallback matches'
    )

    input '<Esc>'
    spin(10)
    expect_eq(fn.mode(1), 'n', 'expected normal mode after select')
    expect_eq(
      #fn.getmatches(),
      0,
      'returning to normal mode from select should rearm the fallback delay'
    )

    spin(90)
    expect(
      #fn.getmatches() > 0,
      'normal mode should restore fallback matches after select'
    )
  end,
}

tests[#tests + 1] = {
  name = 'window switches clear fallback matches from the old window',
  run = function()
    reset_editor()
    new_buffer({ 'foo foo' }, 'lua')
    local win_a = api.nvim_get_current_win()

    vim.cmd('vsplit')
    local win_b = api.nvim_get_current_win()
    new_buffer({ 'bar' }, 'lua')
    api.nvim_set_current_win(win_a)

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']p', prev = '[p' },
    }

    trigger_cursor_moved()
    spin(20)
    expect(
      #fn.getmatches(win_a) > 0,
      'expected initial fallback match in the first window'
    )

    api.nvim_set_current_win(win_b)
    spin(20)

    expect_eq(
      #fn.getmatches(win_a),
      0,
      'switching windows should clear the old window fallback match'
    )
  end,
}

tests[#tests + 1] = {
  name = 'cache hit ratio command reports buffer and total lookups',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      callback {
        [client.id] = {
          result = document_highlights {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          },
        },
      }
      return function() end
    end

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']s', prev = '[s' },
    }

    trigger_cursor_moved()
    spin(20)

    api.nvim_win_set_cursor(0, { 1, 3 })
    trigger_cursor_moved()
    spin(20)

    api.nvim_win_set_cursor(0, { 1, 0 })
    trigger_cursor_moved()
    spin(20)

    local command_output = vim.trim(fn.execute 'BeaconCacheHitRatio')

    expect_eq(request_count, 1, 'expected cached revisit to avoid a new request')
    expect_eq(
      command_output,
      (
        'Beacon LRU cache hit ratio: buffer %d 1/2 hits (50.0%%), total 1/2 hits (50.0%%)'
      ):format(buf),
      'expected hit ratio command to report the cache hit and miss'
    )
  end,
}

for _, clear_before_move in ipairs { false, true } do
  tests[#tests + 1] = {
    name = 'asymmetric keyword highlights stay target-specific with clear='
      .. tostring(clear_before_move),
    run = function()
      reset_editor()
      local buf =
        new_buffer({ 'match item {', '    _ => return Ok(None),', '}' }, 'rust')
      local client = new_client(1, { [buf] = true }, true)
      set_clients { client }
      ---@type integer[][]
      local match_ranges = { { 0, 0, 0, 5 }, { 1, 9, 1, 24 } }
      ---@type integer[][]
      local return_ranges = { { 1, 9, 1, 15 } }
      local request_count = 0
      lsp_state.request_handler = function(_, _, params, callback)
        request_count = request_count + 1
        local row = params(client).position.line
        callback {
          [client.id] = {
            result = document_highlights(
              row == 0 and match_ranges or return_ranges
            ),
          },
        }
        return function() end
      end
      beacon.setup { delay_ms = 0, lsp_attach_timeout_ms = 0 }
      trigger_cursor_moved()
      spin(25)
      expect_highlight_ranges(
        buf,
        match_ranges,
        'match should render its broad result'
      )

      if clear_before_move then
        api.nvim_win_set_cursor(0, { 1, 5 })
        trigger_cursor_moved()
        expect_eq(extmark_count(buf), 0, 'whitespace should clear active state')
      end
      api.nvim_win_set_cursor(0, { 2, 9 })
      trigger_cursor_moved()
      expect_eq(extmark_count(buf), clear_before_move and 0 or 2, 'only an already-visible result may remain while return is resolved')
      spin(25)
      expect_eq(
        request_count,
        2,
        'return needs its own response even inside a cached range'
      )
      expect_highlight_ranges(
        buf,
        return_ranges,
        'return should render only its own result'
      )

      api.nvim_win_set_cursor(0, { 1, 1 })
      trigger_cursor_moved()
      spin(25)
      expect_highlight_ranges(
        buf,
        match_ranges,
        'revisiting match should restore its result'
      )
      api.nvim_win_set_cursor(0, { 2, 10 })
      trigger_cursor_moved()
      spin(25)
      expect_highlight_ranges(
        buf,
        return_ranges,
        'revisiting return should restore its result'
      )
      expect_eq(
        request_count,
        2,
        'revisits should reuse the two originating entries'
      )
    end,
  }
end

for _, first_row in ipairs { 3, 4 } do
  tests[#tests + 1] = {
    name = 'equal-word shorthand highlights stay target-specific starting on row '
      .. first_row,
    run = function()
      reset_editor()
      local buf = new_buffer({
        'struct S { value: i32 }',
        'fn demo() {',
        '    let value = 1;',
        '    let s = S { value };',
        '    let _ = value;',
        '    let _ = s.value;',
        '}',
      }, 'rust')
      local client = new_client(1, { [buf] = true }, true)
      set_clients { client }
      ---@type integer[][]
      local local_ranges =
        { { 2, 8, 2, 13 }, { 3, 16, 3, 21 }, { 4, 12, 4, 17 } }
      ---@type integer[][]
      local shorthand_ranges = {
        { 0, 11, 0, 16 },
        { 2, 8, 2, 13 },
        { 3, 16, 3, 21 },
        { 4, 12, 4, 17 },
        { 5, 14, 5, 19 },
      }
      local request_count = 0
      lsp_state.request_handler = function(_, _, params, callback)
        request_count = request_count + 1
        local row = params(client).position.line
        callback {
          [client.id] = {
            result = document_highlights(
              row == 2 and local_ranges or shorthand_ranges
            ),
          },
        }
        return function() end
      end
      api.nvim_win_set_cursor(0, { first_row, first_row == 3 and 8 or 16 })
      beacon.setup { delay_ms = 0, lsp_attach_timeout_ms = 0 }
      local other_row = first_row == 3 and 4 or 3
      for index, row in ipairs { first_row, other_row, first_row, other_row } do
        api.nvim_win_set_cursor(0, { row, row == 3 and 8 or 16 })
        trigger_cursor_moved()
        spin(25)
        expect_eq(
          request_count,
          math.min(index, 2),
          'each occurrence should request once and then hit its own cache'
        )
        expect_highlight_ranges(
          buf,
          row == 3 and local_ranges or shorthand_ranges,
          'equal text must not imply symmetric results'
        )
      end
    end,
  }
end

tests[#tests + 1] = {
  name = 'identical cached results switch ownership without flicker',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }
    ---@type integer[][]
    local ranges = { { 0, 0, 0, 3 }, { 0, 4, 0, 7 }, { 0, 8, 0, 11 } }
    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      callback { [client.id] = { result = document_highlights(ranges) } }
      return function() end
    end
    beacon.setup {
      delay_ms = 60,
      lsp_miss_delay_ms = 0,
      lsp_attach_timeout_ms = 0,
    }
    trigger_cursor_moved()
    spin(80)
    api.nvim_win_set_cursor(0, { 1, 1 })
    trigger_cursor_moved()
    expect_highlight_ranges(
      buf,
      ranges,
      'moving inside one occurrence should keep visible highlights'
    )
    expect_eq(request_count, 1, 'same occurrence should not request again')

    local initial_marks = api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })
    for index, col in ipairs { 4, 8 } do
      api.nvim_win_set_cursor(0, { 1, col })
      trigger_cursor_moved()
      expect_eq(
        extmark_count(buf),
        3,
        'an uncached highlighted occurrence should retain the previous display'
      )
      spin(80)
      expect_eq(
        request_count,
        index + 1,
        'each occurrence needs its own initial response'
      )
      expect(vim.deep_equal(api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true }), initial_marks), 'identical fresh results must preserve extmark IDs')
    end

    local visible_marks =
      api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })
    for _, col in ipairs { 0, 4, 8 } do
      api.nvim_win_set_cursor(0, { 1, col })
      trigger_cursor_moved()
      expect(
        vim.deep_equal(
          api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true }),
          visible_marks
        ),
        'identical cached result must preserve extmark IDs and details immediately'
      )
      -- A second move inside this occurrence must be keep_active, not another hit.
      api.nvim_win_set_cursor(0, { 1, col + 1 })
      trigger_cursor_moved()
    end
    spin(80)
    expect_eq(
      request_count,
      3,
      'cached transitions must not issue more requests'
    )
    expect(
      vim.deep_equal(
        api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true }),
        visible_marks
      ),
      'cached transitions must not leave a delayed redraw behind'
    )
    local output = vim.trim(fn.execute('BeaconCacheHitRatio'))
    expect_eq(
      output,
      ('Beacon LRU cache hit ratio: buffer %d 3/6 hits (50.0%%), total 3/6 hits (50.0%%)'):format(
        buf
      ),
      'adoption should count once per transition and update active ownership'
    )

    api.nvim_win_set_cursor(0, { 1, 3 })
    trigger_cursor_moved()
    expect_eq(extmark_count(buf), 0, 'whitespace must clear the visible entry')
    api.nvim_win_set_cursor(0, { 1, 0 })
    trigger_cursor_moved()
    spin(20)
    expect_eq(
      extmark_count(buf),
      0,
      'cached result with no visible entry must still wait for the cursor dwell'
    )
    spin(60)
    expect_highlight_ranges(
      buf,
      ranges,
      'cached result should render after the delay'
    )
    expect_eq(request_count, 3, 'cached revisit must not request again')
  end,
}

for _, difference in ipairs { 'span', 'kind' } do
  tests[#tests + 1] = {
    name = 'cached results with different '
      .. difference
      .. ' still clear and wait',
    run = function()
      reset_editor()
      local buf = new_buffer({ 'foo foo foo' }, 'lua')
      local client = new_client(1, { [buf] = true }, true)
      set_clients { client }
      local request_count = 0
      lsp_state.request_handler = function(_, _, params, callback)
        request_count = request_count + 1
        local is_second = params(client).position.character == 4
        local end_col = is_second and difference == 'span' and 11 or 7
        local kind = is_second and difference == 'kind' and 3 or 2
        callback {
          [client.id] = {
            result = document_highlights {
              { 0, 0, 0, 3, kind },
              { 0, 4, 0, end_col, kind },
            },
          },
        }
        return function() end
      end
      beacon.setup {
        delay_ms = 60,
        lsp_miss_delay_ms = 0,
        lsp_attach_timeout_ms = 0,
      }
      for index, col in ipairs { 0, 4, 0, 4 } do
        api.nvim_win_set_cursor(0, { 1, col })
        trigger_cursor_moved()
        expect_eq(
          extmark_count(buf),
          index == 2 and 2 or 0,
          'only the first unknown destination may retain the previous display'
        )
        spin(20)
        expect_eq(
          extmark_count(buf),
          index == 2 and 2 or 0,
          'known different output must clear during the dwell'
        )
        spin(60)
        local end_col = col == 4 and difference == 'span' and 11 or 7
        expect_highlight_ranges(
          buf,
          { { 0, 0, 0, 3 }, { 0, 4, 0, end_col } },
          'destination ranges must render after the delay'
        )
        local group = col == 4 and difference == 'kind' and 'BeaconWrite'
          or 'BeaconRead'
        for _, mark in
          ipairs(
            api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })
          )
        do
          expect_eq(
            mark[4].hl_group,
            group,
            'destination highlight kind must be preserved'
          )
        end
      end
      expect_eq(
        request_count,
        2,
        'differing cached responses should still avoid extra requests'
      )
    end,
  }
end

tests[#tests + 1] = {
  name = 'stale identical cache entries cannot satisfy a new target',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }
    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      callback {
        [client.id] = {
          result = document_highlights { { 0, 0, 0, 3 }, { 0, 4, 0, 7 } },
        },
      }
      return function() end
    end
    beacon.setup {
      delay_ms = 60,
      lsp_miss_delay_ms = 0,
      lsp_attach_timeout_ms = 0,
    }
    trigger_cursor_moved()
    spin(80)
    api.nvim_win_set_cursor(0, { 1, 4 })
    trigger_cursor_moved()
    spin(80)
    expect_eq(request_count, 2, 'both occurrences should be cached')
    api.nvim_exec_autocmds('LspProgress', {
      modeline = false,
      pattern = 'end',
      data = { client_id = client.id, params = { value = { kind = 'end' } } },
    })
    expect_eq(request_count, 3, 'progress should refresh the active target')
    expect_eq(extmark_count(buf), 2, 'refreshed highlights should be visible')
    api.nvim_win_set_cursor(0, { 1, 0 })
    trigger_cursor_moved()
    expect_eq(
      extmark_count(buf),
      2,
      'the refreshed visible result may remain while the stale destination is requested'
    )
    spin(80)
    expect_eq(request_count, 4, 'stale destination needs a fresh response')
  end,
}

tests[#tests + 1] = {
  name = 'late responses only render at their originating target',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }
    ---@type BeaconTestResponseCallback[]
    local callbacks = {}
    lsp_state.request_handler = function(_, _, _, callback)
      callbacks[#callbacks + 1] = callback
      return function() end
    end
    ---@type integer[][]
    local broad = { { 0, 0, 0, 3 }, { 0, 4, 0, 7 } }
    ---@type integer[][]
    local narrow = { { 0, 4, 0, 7 } }
    beacon.setup { delay_ms = 0, lsp_attach_timeout_ms = 0 }
    trigger_cursor_moved()
    spin(25)
    expect_eq(#callbacks, 1, 'first request should be pending')

    -- Move without dispatching CursorMoved to exercise response-time validation.
    api.nvim_win_set_cursor(0, { 1, 4 })
    callbacks[1] { [client.id] = { result = document_highlights(broad) } }
    expect_eq(
      extmark_count(buf),
      0,
      'late result must not render at a different covered occurrence'
    )
    trigger_cursor_moved()
    spin(25)
    expect_eq(#callbacks, 2, 'second occurrence must not reuse the late result')
    callbacks[2] { [client.id] = { result = document_highlights(narrow) } }
    expect_highlight_ranges(
      buf,
      narrow,
      'second response should render at its target'
    )
    callbacks[1] { [client.id] = { result = document_highlights(broad) } }
    expect_highlight_ranges(
      buf,
      narrow,
      'obsolete callbacks must not replace current highlights'
    )

    api.nvim_win_set_cursor(0, { 1, 0 })
    trigger_cursor_moved()
    spin(25)
    expect_eq(
      #callbacks,
      2,
      'valid late response should remain cached for its original target'
    )
    expect_highlight_ranges(
      buf,
      broad,
      'original target should reuse its late response'
    )
  end,
}

tests[#tests + 1] = {
  name = 'edited-buffer responses are rejected before range conversion',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo', 'foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }
    ---@type BeaconTestResponseCallback[]
    local callbacks = {}
    lsp_state.request_handler = function(_, _, _, callback)
      callbacks[#callbacks + 1] = callback
      return function() end
    end
    beacon.setup { delay_ms = 0, lsp_attach_timeout_ms = 0 }
    trigger_cursor_moved()
    spin(25)
    api.nvim_buf_set_lines(buf, 1, -1, false, {})
    callbacks[1] {
      [client.id] = { result = document_highlights { { 1, 0, 1, 3 } } },
    }
    expect_eq(
      extmark_count(buf),
      0,
      'response for the old changedtick must not render'
    )
    trigger_cursor_moved()
    spin(25)
    expect_eq(#callbacks, 2, 'edited target needs a fresh request')
  end,
}

for _, destination_col in ipairs { 3, 4 } do
  tests[#tests + 1] = {
    name = 'delayed resolution rechecks the target at column '
      .. destination_col,
    run = function()
      reset_editor()
      local buf = new_buffer({ 'foo foo' }, 'lua')
      local client = new_client(1, { [buf] = true }, true)
      set_clients { client }
      ---@type integer[]
      local requested_cols = {}
      lsp_state.request_handler = function(_, _, params, callback)
        local col = params(client).position.character
        requested_cols[#requested_cols + 1] = col
        callback {
          [client.id] = {
            result = document_highlights { { 0, col, 0, col + 3 } },
          },
        }
        return function() end
      end
      beacon.setup {
        delay_ms = 80,
        lsp_miss_delay_ms = 0,
        lsp_attach_timeout_ms = 0,
      }
      trigger_cursor_moved()
      api.nvim_win_set_cursor(0, { 1, destination_col })
      spin(100)
      expect_eq(
        #requested_cols,
        0,
        'changed or missing target must not use the expired dwell'
      )
      expect_eq(extmark_count(buf), 0, 'stale delayed work must not render')
      spin(100)
      expect_eq(
        #requested_cols,
        destination_col == 4 and 1 or 0,
        'only a current keyword should be resolved after its new delay'
      )
      if destination_col == 4 then
        expect_eq(
          requested_cols[1],
          4,
          'request should use the new occurrence position'
        )
      end
      api.nvim_win_set_cursor(0, { 1, 0 })
      trigger_cursor_moved()
      spin(100)
      expect_eq(
        requested_cols[#requested_cols],
        0,
        'original occurrence must not inherit the new occurrence response'
      )
      expect_eq(
        #requested_cols,
        destination_col == 4 and 2 or 1,
        'original occurrence must still be a cache miss'
      )
    end,
  }
end

tests[#tests + 1] = {
  name = 'a queued callback cannot consume a replacement timer',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }
    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      callback {
        [client.id] = { result = document_highlights { { 0, 4, 0, 7 } } },
      }
      return function() end
    end
    beacon.setup {
      delay_ms = 80,
      lsp_miss_delay_ms = 0,
      lsp_attach_timeout_ms = 0,
    }

    -- Capture scheduled callbacks so the old one can be delivered after cancel.
    ---@type (fun())[]
    local scheduled = {}
    local original_schedule_wrap = vim.schedule_wrap
    rawset(vim, 'schedule_wrap', function(callback)
      scheduled[#scheduled + 1] = callback
      return original_schedule_wrap(callback)
    end)
    local ok, err = pcall(function()
      trigger_cursor_moved()
      api.nvim_win_set_cursor(0, { 1, 4 })
      trigger_cursor_moved()
    end)
    rawset(vim, 'schedule_wrap', original_schedule_wrap)
    expect(ok, tostring(err))
    expect_eq(#scheduled, 2, 'each occurrence should schedule its own timer')
    scheduled[1]()
    expect_eq(
      request_count,
      0,
      'old callback must not resolve the replacement timer early'
    )
    spin(100)
    expect_eq(
      request_count,
      1,
      'replacement timer should still resolve its target'
    )
    expect_highlight_ranges(
      buf,
      { { 0, 4, 0, 7 } },
      'replacement timer should retain its response ownership'
    )
  end,
}

tests[#tests + 1] = {
  name = 'responses need not include their originating target in the returned ranges',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }
    ---@type integer[][]
    local ranges = { { 0, 4, 0, 7 } }
    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      callback { [client.id] = { result = document_highlights(ranges) } }
      return function() end
    end
    beacon.setup { delay_ms = 0, lsp_attach_timeout_ms = 0 }
    trigger_cursor_moved()
    spin(25)
    expect_highlight_ranges(
      buf,
      ranges,
      'response ownership should determine rendering'
    )
    api.nvim_win_set_cursor(0, { 1, 1 })
    trigger_cursor_moved()
    expect_eq(
      request_count,
      1,
      'same target should keep its result even outside the returned ranges'
    )
    api.nvim_win_set_cursor(0, { 1, 3 })
    trigger_cursor_moved()
    api.nvim_win_set_cursor(0, { 1, 0 })
    trigger_cursor_moved()
    spin(25)
    expect_eq(
      request_count,
      1,
      'originating target should reuse its cached response'
    )
    expect_highlight_ranges(
      buf,
      ranges,
      'cached response should render outside its ranges too'
    )
  end,
}

tests[#tests + 1] = {
  name = 'latency prediction command reports learned client latency',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    lsp_state.request_handler = function(_, _, _, callback)
      local timer = assert(vim.uv.new_timer(), 'expected request timer')
      local closed = false

      local function close_timer()
        if closed then
          return
        end
        closed = true
        timer:stop()
        timer:close()
      end

      timer:start(
        40,
        0,
        vim.schedule_wrap(function()
          close_timer()
          callback {
            [client.id] = {
              result = document_highlights {
                { 0, 0, 0, 3 },
                { 0, 4, 0, 7 },
              },
            },
          }
        end)
      )

      return close_timer
    end

    beacon.setup {
      delay_ms = 80,
      lsp_miss_delay_ms = 0,
      lsp_miss_delay_min_ms = 10,
      lsp_latency_samples = 2,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']s', prev = '[s' },
    }

    trigger_cursor_moved()
    spin(100)
    spin(60)

    local command_output = vim.trim(fn.execute 'BeaconLspLatencyPrediction')
    local pattern =
      '^Beacon LSP latency prediction: buffer '
      .. buf
      .. ' miss delay (%d+)ms %(delay_ms=(%d+), predicted=(%d+)ms, min=(%d+)ms%), clients: client 1 (%d+)ms %((.+)%)$'
    local miss_delay, total_delay, predicted, min_delay, client_latency, sample_text =
      command_output:match(pattern)

    expect(miss_delay ~= nil, 'expected latency prediction command format')
    expect_eq(total_delay, '80', 'expected latency prediction to report delay_ms')
    expect_eq(min_delay, '10', 'expected latency prediction to report min delay')
    expect_eq(
      predicted,
      client_latency,
      'expected client latency to match the predicted request latency'
    )
    expect_eq(sample_text, '1/2 samples', 'expected one learned latency sample')
    expect_eq(
      tonumber(miss_delay) + tonumber(predicted),
      80,
      'expected miss delay to subtract the predicted latency from delay_ms'
    )
  end,
}

tests[#tests + 1] = {
  name = 'latency prediction uses the last n samples',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo bar bar baz baz' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    local request_delays = { 20, 20, 100 }
    local request_index = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_index = request_index + 1
      local timer = assert(vim.uv.new_timer(), 'expected request timer')
      local cursor_col = api.nvim_win_get_cursor(0)[2]
      local delay = request_delays[request_index]
      local ranges = cursor_col < 8
          and {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          }
        or cursor_col < 16
          and {
            { 0, 8, 0, 11 },
            { 0, 12, 0, 15 },
          }
        or {
          { 0, 16, 0, 19 },
          { 0, 20, 0, 23 },
        }
      local closed = false

      local function close_timer()
        if closed then
          return
        end
        closed = true
        timer:stop()
        timer:close()
      end

      timer:start(
        delay,
        0,
        vim.schedule_wrap(function()
          close_timer()
          callback {
            [client.id] = {
              result = document_highlights(ranges),
            },
          }
        end)
      )

      return close_timer
    end

    beacon.setup {
      delay_ms = 120,
      lsp_miss_delay_ms = 0,
      lsp_miss_delay_min_ms = 10,
      lsp_latency_samples = 2,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']t', prev = '[t' },
    }

    trigger_cursor_moved()
    spin(150)
    spin(40)
    api.nvim_win_set_cursor(0, { 1, 3 })
    trigger_cursor_moved()
    spin(20)

    api.nvim_win_set_cursor(0, { 1, 8 })
    trigger_cursor_moved()
    spin(130)
    spin(40)
    api.nvim_win_set_cursor(0, { 1, 11 })
    trigger_cursor_moved()
    spin(20)

    api.nvim_win_set_cursor(0, { 1, 16 })
    trigger_cursor_moved()
    spin(130)
    spin(120)

    local command_output = vim.trim(fn.execute 'BeaconLspLatencyPrediction')
    local pattern =
      '^Beacon LSP latency prediction: buffer '
      .. buf
      .. ' miss delay (%d+)ms %(delay_ms=(%d+), predicted=(%d+)ms, min=(%d+)ms%), clients: client 1 (%d+)ms %((.+)%)$'
    local miss_delay, total_delay, predicted, min_delay, client_latency, sample_text =
      command_output:match(pattern)

    expect(miss_delay ~= nil, 'expected latency prediction command format')
    expect_eq(total_delay, '120', 'expected latency prediction to report delay_ms')
    expect_eq(min_delay, '10', 'expected latency prediction to report min delay')
    expect_eq(sample_text, '2/2 samples', 'expected the prediction window to be full')
    expect_eq(
      predicted,
      client_latency,
      'expected client latency to match the predicted request latency'
    )
    expect(
      tonumber(predicted) >= 55,
      'expected prediction to be driven by the last two samples, not the full history'
    )
    expect_eq(
      tonumber(miss_delay) + tonumber(predicted),
      120,
      'expected miss delay to subtract the predicted latency from delay_ms'
    )
  end,
}

tests[#tests + 1] = {
  name = 'fallback mode does not change cache hit ratio',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    lsp_state.request_handler = function(_, _, _, callback)
      callback {
        [client.id] = {
          result = document_highlights {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          },
        },
      }
      return function() end
    end

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']t', prev = '[t' },
    }

    trigger_cursor_moved()
    spin(20)

    api.nvim_win_set_cursor(0, { 1, 3 })
    trigger_cursor_moved()
    spin(20)

    api.nvim_win_set_cursor(0, { 1, 0 })
    trigger_cursor_moved()
    spin(20)

    set_clients {}
    test_lsp.config = {}
    test_lsp._enabled_configs = {}
    api.nvim_exec_autocmds('LspDetach', { buffer = buf, modeline = false })

    api.nvim_win_set_cursor(0, { 1, 0 })
    trigger_cursor_moved()
    spin(20)

    api.nvim_win_set_cursor(0, { 1, 4 })
    trigger_cursor_moved()
    spin(20)

    local command_output = vim.trim(fn.execute 'BeaconCacheHitRatio')
    expect_eq(
      command_output,
      (
        'Beacon LRU cache hit ratio: buffer %d 1/2 hits (50.0%%), total 1/2 hits (50.0%%)'
      ):format(buf),
      'fallback mode should not change buffer or total cache ratios'
    )
  end,
}

tests[#tests + 1] = {
  name = 'cache miss delay respects the configured lower bound',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo bar bar' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      local timer = assert(vim.uv.new_timer(), 'expected request timer')
      local cursor_col = api.nvim_win_get_cursor(0)[2]
      local ranges = cursor_col < 8
          and {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          }
        or {
          { 0, 8, 0, 11 },
          { 0, 12, 0, 15 },
        }
      local closed = false

      local function close_timer()
        if closed then
          return
        end
        closed = true
        timer:stop()
        timer:close()
      end

      timer:start(
        100,
        0,
        vim.schedule_wrap(function()
          close_timer()
          callback {
            [client.id] = {
              result = document_highlights(ranges),
            },
          }
        end)
      )

      return close_timer
    end

    beacon.setup {
      delay_ms = 60,
      lsp_miss_delay_ms = 0,
      lsp_miss_delay_min_ms = 25,
      lsp_latency_samples = 2,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']t', prev = '[t' },
    }

    trigger_cursor_moved()
    spin(80)
    expect_eq(request_count, 1, 'expected the initial miss request to start')
    spin(120)

    api.nvim_win_set_cursor(0, { 1, 3 })
    trigger_cursor_moved()
    spin(20)

    api.nvim_win_set_cursor(0, { 1, 8 })
    trigger_cursor_moved()
    spin(20)
    expect_eq(
      request_count,
      1,
      'expected the miss-delay floor to prevent an immediate second request'
    )

    spin(30)
    expect_eq(
      request_count,
      2,
      'expected the second miss request to start after the configured floor'
    )
  end,
}

tests[#tests + 1] = {
  name = 'learned LSP latency shortens later cache misses in the same buffer',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo bar bar' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      local timer = assert(vim.uv.new_timer(), 'expected request timer')
      local cursor_col = api.nvim_win_get_cursor(0)[2]
      local ranges = cursor_col < 8
          and {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          }
        or {
          { 0, 8, 0, 11 },
          { 0, 12, 0, 15 },
        }
      local closed = false

      local function close_timer()
        if closed then
          return
        end
        closed = true
        timer:stop()
        timer:close()
      end

      timer:start(
        40,
        0,
        vim.schedule_wrap(function()
          close_timer()
          callback {
            [client.id] = {
              result = document_highlights(ranges),
            },
          }
        end)
      )

      return close_timer
    end

    beacon.setup {
      delay_ms = 80,
      lsp_miss_delay_ms = 0,
      lsp_miss_delay_min_ms = 10,
      lsp_latency_samples = 2,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']t', prev = '[t' },
    }

    trigger_cursor_moved()
    spin(40)
    expect_eq(
      request_count,
      0,
      'first miss should wait for the full dwell before the request starts'
    )

    spin(60)
    expect_eq(
      request_count,
      1,
      'expected the delayed first LSP request'
    )
    spin(60)
    expect(
      extmark_count(buf) > 0,
      'expected the first LSP response to render extmarks'
    )

    api.nvim_win_set_cursor(0, { 1, 3 })
    trigger_cursor_moved()
    spin(20)
    expect_eq(extmark_count(buf), 0, 'whitespace should clear active extmarks')

    api.nvim_win_set_cursor(0, { 1, 8 })
    trigger_cursor_moved()
    spin(20)
    expect_eq(
      request_count,
      1,
      'learned latency should still leave some delay before the next miss request'
    )

    spin(40)
    expect_eq(
      request_count,
      2,
      'learned latency should shorten the next miss delay in the same buffer'
    )
    spin(60)
    expect(extmark_count(buf) > 0, 'expected the second LSP response to render')
  end,
}

tests[#tests + 1] = {
  name = 'learned LSP latency stays buffer local',
  run = function()
    reset_editor()
    local buf_a = new_buffer({ 'foo foo' }, 'lua')
    local buf_b = api.nvim_create_buf(true, false)
    api.nvim_buf_set_lines(buf_b, 0, -1, false, { 'foo foo' })
    vim.bo[buf_b].buftype = ''
    vim.bo[buf_b].filetype = 'lua'
    api.nvim_exec_autocmds('FileType', { buffer = buf_b, modeline = false })
    local client = new_client(1, { [buf_a] = true, [buf_b] = true }, true)
    set_clients { client }

    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      local timer = assert(vim.uv.new_timer(), 'expected request timer')
      local closed = false

      local function close_timer()
        if closed then
          return
        end
        closed = true
        timer:stop()
        timer:close()
      end

      timer:start(
        40,
        0,
        vim.schedule_wrap(function()
          close_timer()
          callback {
            [client.id] = {
              result = document_highlights {
                { 0, 0, 0, 3 },
                { 0, 4, 0, 7 },
              },
            },
          }
        end)
      )

      return close_timer
    end

    beacon.setup {
      delay_ms = 80,
      lsp_miss_delay_ms = 0,
      lsp_miss_delay_min_ms = 10,
      lsp_latency_samples = 2,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']t', prev = '[t' },
    }

    trigger_cursor_moved()
    spin(100)
    spin(60)
    expect_eq(request_count, 1, 'expected the first buffer to issue one request')

    api.nvim_set_current_buf(buf_b)
    api.nvim_win_set_cursor(0, { 1, 0 })
    trigger_cursor_moved()
    spin(20)
    expect_eq(
      request_count,
      1,
      'second buffer should not reuse the first buffer latency prediction'
    )

    spin(80)
    expect_eq(
      request_count,
      2,
      'second buffer should still wait for its own initial miss delay'
    )
  end,
}

tests[#tests + 1] = {
  name = 'same-target pending LSP misses rearm delay after cursor movement',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      local timer = assert(vim.uv.new_timer(), 'expected request timer')
      local closed = false

      local function close_timer()
        if closed then
          return
        end
        closed = true
        timer:stop()
        timer:close()
      end

      timer:start(
        20,
        0,
        vim.schedule_wrap(function()
          close_timer()
          callback {
            [client.id] = {
              result = document_highlights {
                { 0, 0, 0, 3 },
                { 0, 4, 0, 7 },
              },
            },
          }
        end)
      )

      return close_timer
    end

    beacon.setup {
      delay_ms = 60,
      lsp_miss_delay_ms = 0,
      lsp_miss_delay_min_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']t', prev = '[t' },
    }

    trigger_cursor_moved()
    spin(70)
    expect_eq(request_count, 1, 'expected the initial delayed LSP request')
    expect_eq(extmark_count(buf), 0, 'response should still be pending')

    api.nvim_win_set_cursor(0, { 1, 1 })
    trigger_cursor_moved()
    spin(30)

    expect_eq(
      extmark_count(buf),
      0,
      'same-target cursor movement should rearm delay before rendering'
    )
    expect_eq(
      request_count,
      1,
      'same-target cursor movement should not start the next request early'
    )

    spin(40)
    expect_eq(
      request_count,
      1,
      'same-target cursor movement should keep the original request in flight'
    )

    expect(
      extmark_count(buf) > 0,
      'the rearmed same-target dwell should eventually render extmarks'
    )
  end,
}

tests[#tests + 1] = {
  name = 'fallback highlights wait for delay before matching',
  run = function()
    reset_editor()
    new_buffer({ 'foo foo' }, 'lua')

    beacon.setup {
      delay_ms = 60,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']t', prev = '[t' },
    }

    trigger_cursor_moved()
    spin(10)
    expect_eq(#fn.getmatches(), 0, 'fallback should wait before adding a match')

    spin(90)
    expect(#fn.getmatches() > 0, 'fallback should add a match after the delay')

    api.nvim_win_set_cursor(0, { 1, 3 })
    trigger_cursor_moved()
    spin(20)
    expect_eq(#fn.getmatches(), 0, 'whitespace should clear the fallback match')

    api.nvim_win_set_cursor(0, { 1, 4 })
    trigger_cursor_moved()
    spin(10)
    expect_eq(
      #fn.getmatches(),
      0,
      'fallback revisit should still wait before adding a match'
    )

    spin(90)
    expect(
      #fn.getmatches() > 0,
      'fallback revisit should add a match after the delay'
    )
  end,
}

tests[#tests + 1] = {
  name = 'detach invalidates cached LSP entries before fallback',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    lsp_state.request_handler = function(_, _, _, callback)
      callback {
        [client.id] = {
          result = document_highlights {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          },
        },
      }
      return function() end
    end

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']t', prev = '[t' },
    }

    trigger_cursor_moved()
    spin(20)
    expect(extmark_count(buf) > 0, 'expected initial LSP extmarks')

    set_clients {}
    test_lsp.config = {}
    test_lsp._enabled_configs = {}
    api.nvim_exec_autocmds('LspDetach', { buffer = buf, modeline = false })

    api.nvim_win_set_cursor(0, { 1, 4 })
    trigger_cursor_moved()
    spin(20)

    expect_eq(
      extmark_count(buf),
      0,
      'detach should not reuse cached LSP extmarks'
    )
    expect(#fn.getmatches() > 0, 'detach should fall back to a window match')
  end,
}

tests[#tests + 1] = {
  name = 'clear cancels delayed highlight timers',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')

    beacon.setup {
      delay_ms = 60,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']u', prev = '[u' },
    }

    trigger_cursor_moved()
    spin(10)
    beacon.clear(buf)
    spin(90)

    expect_eq(extmark_count(buf), 0, 'clear should remove LSP extmarks')
    expect_eq(#fn.getmatches(), 0, 'clear should keep fallback matches cleared')
  end,
}

tests[#tests + 1] = {
  name = 'fallback navigation skips the current match',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo foo' }, 'lua')

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']u', prev = '[u' },
    }

    api.nvim_win_set_cursor(0, { 1, 5 })
    trigger_cursor_moved()
    spin(20)
    expect(#fn.getmatches() > 0, 'expected fallback highlight to be active')

    beacon.prev_reference()
    expect_eq(
      api.nvim_win_get_cursor(0)[2],
      0,
      'fallback prev should skip the current match and jump to the previous one'
    )

    api.nvim_win_set_cursor(0, { 1, 5 })
    trigger_cursor_moved()
    spin(20)

    beacon.next_reference()
    expect_eq(
      api.nvim_win_get_cursor(0)[2],
      8,
      'fallback next should jump to the next match from the current word'
    )

    expect_eq(
      buf,
      api.nvim_get_current_buf(),
      'fallback navigation should stay in the current buffer'
    )
  end,
}

tests[#tests + 1] = {
  name = 'text changes replace delayed LSP target resolution with the current target',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      callback {
        [client.id] = {
          result = document_highlights {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          },
        },
      }
      return function() end
    end

    beacon.setup {
      delay_ms = 60,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']u', prev = '[u' },
    }

    trigger_cursor_moved()
    spin(10)

    api.nvim_buf_set_lines(buf, 0, -1, false, { 'bar bar' })
    api.nvim_exec_autocmds('TextChanged', { buffer = buf, modeline = false })
    spin(20)

    expect_eq(
      request_count,
      0,
      'text changes should cancel the stale delayed LSP request before the delay elapses'
    )

    spin(80)

    expect_eq(
      request_count,
      1,
      'text changes should rearm a single delayed LSP request for the current target'
    )
    expect(extmark_count(buf) > 0, 'text changes should re-highlight without cursor motion')
  end,
}

tests[#tests + 1] = {
  name = 'navigation revalidates stale active ranges',
  run = function()
    reset_editor()
    local buf_a = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf_a] = true }, true)
    set_clients { client }

    local generation = 1
    lsp_state.request_handler = function(_, _, _, callback)
      local ranges = generation == 1
          and {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          }
        or {
          { 0, 0, 0, 3 },
        }

      callback {
        [client.id] = {
          result = document_highlights(ranges),
        },
      }
      return function() end
    end

    beacon.setup {
      delay_ms = 100,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']v', prev = '[v' },
    }

    trigger_cursor_moved()
    spin(20)

    local buf_b = new_buffer({ 'bar' }, 'lua')
    api.nvim_set_current_buf(buf_b)
    generation = 2
    api.nvim_exec_autocmds('LspProgress', {
      modeline = false,
      data = { client_id = client.id, params = { value = { kind = 'end' } } },
    })

    api.nvim_set_current_buf(buf_a)
    api.nvim_win_set_cursor(0, { 1, 0 })
    beacon.next_reference()

    local cursor = api.nvim_win_get_cursor(0)
    expect_eq(
      cursor[2],
      0,
      'navigation should not jump using stale active ranges'
    )
  end,
}

tests[#tests + 1] = {
  name = 'navigation requests the current target instead of using another targets ranges',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }
    ---@type BeaconTestResponseCallback[]
    local callbacks = {}
    lsp_state.request_handler = function(_, _, _, callback)
      callbacks[#callbacks + 1] = callback
      return function() end
    end
    beacon.setup { delay_ms = 0, lsp_attach_timeout_ms = 0 }
    trigger_cursor_moved()
    spin(25)
    callbacks[1] {
      [client.id] = {
        result = document_highlights { { 0, 0, 0, 3 }, { 0, 4, 0, 7 } },
      },
    }
    api.nvim_win_set_cursor(0, { 1, 4 })
    beacon.next_reference()
    expect_eq(
      api.nvim_win_get_cursor(0)[2],
      4,
      'navigation must not jump using the previous target'
    )
    expect_eq(
      extmark_count(buf),
      2,
      'navigation may retain the previous display while resolving the new target'
    )
    expect_eq(#callbacks, 2, 'navigation should request the new target')
    callbacks[2] {
      [client.id] = {
        result = document_highlights { { 0, 4, 0, 7 }, { 0, 8, 0, 11 } },
      },
    }
    expect_eq(
      api.nvim_win_get_cursor(0)[2],
      4,
      'response must not execute a queued jump'
    )
    beacon.next_reference()
    expect_eq(
      api.nvim_win_get_cursor(0)[2],
      8,
      'next jump should use the new target result'
    )
    expect_eq(
      #callbacks,
      2,
      'navigation from a resolved target should not request again'
    )
  end,
}

tests[#tests + 1] = {
  name = 'overlapping ranges do not force a second request',
  run = function()
    reset_editor()
    local line = string.rep('f', 120)
    local buf = new_buffer({ line }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    local request_count = 0
    lsp_state.request_handler = function(_, _, _, callback)
      request_count = request_count + 1
      callback {
        [client.id] = {
          result = document_highlights {
            { 0, 0, 0, 100 },
            { 0, 10, 0, 20 },
            { 0, 30, 0, 40 },
          },
        },
      }
      return function() end
    end

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']w', prev = '[w' },
    }

    trigger_cursor_moved()
    spin(20)
    expect_eq(request_count, 1, 'expected one initial request')

    api.nvim_win_set_cursor(0, { 1, 50 })
    trigger_cursor_moved()
    spin(20)

    expect_eq(
      request_count,
      1,
      'movement within the same keyword should keep the active entry'
    )
    beacon.next_reference()
    expect_eq(
      api.nvim_win_get_cursor(0)[2],
      10,
      'next navigation should find the enclosing outer range'
    )
    beacon.prev_reference()
    expect_eq(
      api.nvim_win_get_cursor(0)[2],
      0,
      'previous navigation should find the nested range'
    )
    expect_eq(
      request_count,
      1,
      'overlapping-range navigation within one keyword should not request again'
    )
  end,
}

tests[#tests + 1] = {
  name = 'reload re-highlights after the restored cursor target settles',
  run = function()
    reset_editor()
    local buf = new_buffer({ 'foo foo' }, 'lua')
    local client = new_client(1, { [buf] = true }, true)
    set_clients { client }

    lsp_state.request_handler = function(_, _, _, callback)
      callback {
        [client.id] = {
          result = document_highlights {
            { 0, 0, 0, 3 },
            { 0, 4, 0, 7 },
          },
        },
      }
      return function() end
    end

    beacon.setup {
      delay_ms = 10,
      lsp_miss_delay_min_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']x', prev = '[x' },
    }

    api.nvim_win_set_cursor(0, { 1, 4 })
    trigger_cursor_moved()
    spin(20)
    expect(extmark_count(buf) > 0, 'expected initial LSP extmarks')

    api.nvim_win_set_cursor(0, { 1, 0 })
    api.nvim_exec_autocmds('FileType', { buffer = buf, modeline = false })
    api.nvim_exec_autocmds('BufReadPost', { buffer = buf, modeline = false })
    api.nvim_exec_autocmds('BufEnter', { buffer = buf, modeline = false })

    -- Reload can restore the original cursor position after the enter events
    -- without emitting a fresh CursorMoved notification.
    api.nvim_win_set_cursor(0, { 1, 4 })
    spin(30)

    expect(
      extmark_count(buf) > 0,
      'reload should re-highlight once the restored cursor target settles'
    )
  end,
}

tests[#tests + 1] = {
  name = 'setup replaces old mappings on reload',
  run = function()
    reset_editor()
    new_buffer({ 'foo' }, 'lua')

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']x', prev = '[x' },
    }
    expect_eq(
      fn.maparg(']x', 'n', false, true).desc,
      'Next document reference',
      'expected first mapping to be installed'
    )

    beacon.setup {
      delay_ms = 0,
      lsp_attach_timeout_ms = 0,
      mappings = { next = ']y', prev = '[y' },
    }

    local old_next = fn.maparg(']x', 'n', false, true)
    expect(
      old_next.desc ~= 'Next document reference',
      'old next mapping should be removed'
    )
    expect_eq(
      fn.maparg(']y', 'n', false, true).desc,
      'Next document reference',
      'new next mapping should be installed'
    )
  end,
}

local failures = {}

for _, test in ipairs(tests) do
  local ok, err = pcall(test.run)
  if not ok then
    failures[#failures + 1] = string.format('%s: %s', test.name, err)
  end
end

test_lsp.get_clients = original_lsp.get_clients
test_lsp.get_client_by_id = original_lsp.get_client_by_id
test_lsp.buf_request_all = original_lsp.buf_request_all
test_lsp.config = original_lsp.config
test_lsp._enabled_configs = original_lsp.enabled_configs
vim.cmd('silent! %bwipeout!')
vim.cmd('enew!')
vim.bo.modified = false

if #failures > 0 then
  error(table.concat(failures, '\n'), 0)
end

print('regressions-ok')
