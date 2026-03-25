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

local original_lsp = {
  get_clients = test_lsp.get_clients,
  get_client_by_id = test_lsp.get_client_by_id,
  buf_request_all = test_lsp.buf_request_all,
  config = test_lsp.config,
  enabled_configs = test_lsp._enabled_configs,
}

---@class BeaconTestState
---@field clients table<integer, BeaconTestClient>
---@field request_handler fun(bufnr: integer, method: string, params: any, callback: fun(results: table<integer, BeaconTestRequestResult>)): fun()
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

    api.nvim_win_set_cursor(0, { 1, 4 })
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

    api.nvim_win_set_cursor(0, { 1, 4 })
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
      'overlapping ranges should keep the active entry'
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
