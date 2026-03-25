local uv = vim.uv or vim.loop
local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local util = vim.lsp.util

---@class BeaconLruCache
---@field get fun(self: BeaconLruCache, key: string): BeaconLspEntry?
---@field set fun(self: BeaconLruCache, key: string, value: BeaconLspEntry)
---@field delete fun(self: BeaconLruCache, key: string)
---@field pairs fun(self: BeaconLruCache): fun(_: nil, prev_key?: string): string?, BeaconLspEntry?

---@class BeaconLruModule
---@field new fun(max_size: integer): BeaconLruCache

---@class BeaconTimer
---@field start fun(self: BeaconTimer, timeout: integer, repeat_interval: integer, callback: fun())
---@field stop fun(self: BeaconTimer)
---@field close fun(self: BeaconTimer)

---@class BeaconResolveOptions
---@field force_lsp? boolean
---@field count_cache_lookup? boolean

---@class BeaconLspRange
---@field start { line: integer, character: integer }
---@field ["end"] { line: integer, character: integer }

---@class BeaconDocumentHighlight
---@field range? BeaconLspRange
---@field kind? integer

---@alias BeaconDocumentHighlightItem BeaconDocumentHighlight|BeaconLspRange

-- Keep the bundled third-party cache implementation namespaced under this
-- plugin so Neovim's runtime loader can resolve it deterministically.
---@type BeaconLruModule
local lru = require('beacon.lru')

---@class BeaconMappings
---@field next? string
---@field prev? string

---@class BeaconMappingsOptions
---@field next? string
---@field prev? string

---@class BeaconHighlightGroups
---@field text string
---@field read string
---@field write string
---@field fallback string

---@class BeaconHighlightGroupsOptions
---@field text? string
---@field read? string
---@field write? string
---@field fallback? string

---@class BeaconConfig
---@field delay_ms integer
---@field lsp_miss_delay_ms integer
---@field lsp_miss_delay_min_ms integer
---@field lsp_latency_samples integer
---@field lsp_attach_timeout_ms integer
---@field max_cache_entries integer
---@field priority integer
---@field fallback_priority integer
---@field wrap_navigation boolean
---@field mappings BeaconMappings
---@field highlight_groups BeaconHighlightGroups
---@field should_attach fun(bufnr: integer): boolean

---@class BeaconConfigOptions
---@field delay_ms? integer
---@field lsp_miss_delay_ms? integer
---@field lsp_miss_delay_min_ms? integer
---@field lsp_latency_samples? integer
---@field lsp_attach_timeout_ms? integer
---@field max_cache_entries? integer
---@field priority? integer
---@field fallback_priority? integer
---@field wrap_navigation? boolean
---@field mappings? BeaconMappingsOptions
---@field highlight_groups? BeaconHighlightGroupsOptions
---@field should_attach? fun(bufnr: integer): boolean

---@class BeaconWord
---@field text string
---@field start_col integer
---@field end_col integer

---@class BeaconRange
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field end_col integer
---@field max_end_row integer
---@field max_end_col integer
---@field kind integer

---@class BeaconTarget
---@field bufnr integer
---@field changedtick integer
---@field row integer
---@field col integer
---@field word string
---@field start_col integer
---@field end_col integer
---@field key string

---@class BeaconLspEntry
---@field key string
---@field bufnr integer
---@field changedtick integer
---@field server_tick integer
---@field ranges BeaconRange[]

---@class BeaconClientLatencyState
---@field latency_ms integer
---@field recent_samples integer[]
---@field sample_count integer
---@field next_sample_index integer
---@field sample_total integer

---@class BeaconPendingRequest
---@field seq integer
---@field server_tick integer
---@field started_at_ms integer
---@field client_ids integer[]
---@field cancel? fun()

---@class BeaconCacheStats
---@field hits integer
---@field misses integer

---@class BeaconBufferState
---@field attach_wait_until integer
---@field server_tick integer
---@field active? BeaconLspEntry
---@field pending? BeaconPendingRequest
---@field cache? BeaconLruCache
---@field cache_stats BeaconCacheStats
---@field client_latencies table<integer, BeaconClientLatencyState>

---@class BeaconWindowState
---@field timer? BeaconTimer
---@field target? BeaconTarget
---@field match_id? integer
---@field match_bufnr? integer
---@field match_word? string
---@field match_changedtick? integer

---@class BeaconInstalledMappings
---@field next? string
---@field prev? string

---@alias BeaconResolveAction
---| 'keep_active'
---| 'keep_fallback'
---| 'use_cache'
---| 'wait'
---| 'fallback'
---| 'request_lsp'

---@class BeaconResolvePlan
---@field action BeaconResolveAction
---@field target BeaconTarget
---@field entry? BeaconLspEntry
---@field wait_ms? integer

---@class BeaconPlanApplyOptions
---@field delay_ms? integer
---@field clear_timer_on_keep? boolean
---@field clear_timer_on_cache? boolean
---@field cancel_pending_on_cache? boolean
---@field record_cache_hit? boolean
---@field clear_active_before_schedule? boolean
---@field cancel_pending_before_schedule? boolean

---@class BeaconCurrentTargetOptions
---@field delay_ms? integer
---@field resolve_opts? BeaconResolveOptions

---@class BeaconState
---@field augroup? integer
---@field buffers table<integer, BeaconBufferState>
---@field windows table<integer, BeaconWindowState>
---@field mappings BeaconInstalledMappings
---@field request_seq integer
---@field cache_stats BeaconCacheStats

---@class BeaconModule
---@field setup fun(opts?: BeaconConfigOptions): BeaconModule
---@field next_reference fun()
---@field prev_reference fun()
---@field clear fun(bufnr?: integer)

local M = {}

local NAMESPACE = api.nvim_create_namespace('beacon')
local DOC_HIGHLIGHT_METHOD = 'textDocument/documentHighlight'

---@type BeaconConfig
local defaults = {
  -- Milliseconds the cursor must stay on a keyword before fallback or cached
  -- highlight work starts.
  delay_ms = 100,
  -- Assumed LSP highlight latency in milliseconds before Beacon has learned a
  -- per-buffer, per-client estimate. Cache-miss debounce subtracts the current
  -- prediction from `delay_ms`.
  lsp_miss_delay_ms = 80,
  -- Minimum debounce used for uncached LSP requests after subtracting the
  -- predicted latency, so cache misses never collapse into request spam.
  lsp_miss_delay_min_ms = 17,
  -- Number of recent latency samples kept per buffer/client prediction.
  lsp_latency_samples = 8,
  -- Milliseconds to wait for an enabled LSP config to attach before falling back to `matchadd()`.
  lsp_attach_timeout_ms = 1000,
  -- Maximum number of cached reference sets kept per buffer for reuse across cursor moves.
  max_cache_entries = 24,
  -- Extmark highlight priority used for LSP-backed references.
  priority = 150,
  -- Window match priority used by the fallback `matchadd()` highlight.
  fallback_priority = 10,
  -- Whether next/previous reference navigation wraps around at the start or end of the list.
  wrap_navigation = true,
  mappings = {
    -- Normal-mode mapping for jumping to the next highlighted reference.
    next = ']r',
    -- Normal-mode mapping for jumping to the previous highlighted reference.
    prev = '[r',
  },
  highlight_groups = {
    -- Highlight group for generic text references returned by the LSP.
    text = 'BeaconText',
    -- Highlight group for read references returned by the LSP.
    read = 'BeaconRead',
    -- Highlight group for write references returned by the LSP.
    write = 'BeaconWrite',
    -- Highlight group used by the fallback `matchadd()` mode.
    fallback = 'BeaconFallback',
  },
  -- Predicate that decides whether a buffer should participate in this plugin at all.
  should_attach = function(bufnr)
    return vim.bo[bufnr].buftype == ''
  end,
}

---@return BeaconCacheStats
local function new_cache_stats()
  return {
    hits = 0,
    misses = 0,
  }
end

---@type BeaconConfig
local config = vim.deepcopy(defaults)

---@type BeaconState
local state = {
  augroup = nil,
  buffers = {},
  windows = {},
  mappings = {},
  request_seq = 0,
  cache_stats = new_cache_stats(),
}

---@param stats BeaconCacheStats
local function reset_cache_stats(stats)
  stats.hits = 0
  stats.misses = 0
end

---@param stats BeaconCacheStats
---@return string
local function format_cache_hit_ratio(stats)
  local lookups = stats.hits + stats.misses
  if lookups == 0 then
    return 'no lookups yet'
  end

  return ('%d/%d hits (%.1f%%)'):format(
    stats.hits,
    lookups,
    (stats.hits / lookups) * 100
  )
end

---@param buf_state BeaconBufferState
local function record_cache_hit(buf_state)
  buf_state.cache_stats.hits = buf_state.cache_stats.hits + 1
  state.cache_stats.hits = state.cache_stats.hits + 1
end

---@param buf_state BeaconBufferState
local function record_cache_miss(buf_state)
  buf_state.cache_stats.misses = buf_state.cache_stats.misses + 1
  state.cache_stats.misses = state.cache_stats.misses + 1
end

local function is_valid_buf(bufnr)
  return bufnr
    and api.nvim_buf_is_valid(bufnr)
    and api.nvim_buf_is_loaded(bufnr)
end

local function is_valid_win(winid)
  return winid and api.nvim_win_is_valid(winid)
end

local function in_normal_mode()
  return fn.mode(1) == 'n'
end

---@param timer BeaconTimer
local function stop_timer(timer)
  if not timer then
    return
  end

  timer:stop()
  timer:close()
end

local function supports_lsp(bufnr)
  return #lsp.get_clients { bufnr = bufnr, method = DOC_HIGHLIGHT_METHOD } > 0
end

local function has_attached_lsp_client(bufnr)
  return #lsp.get_clients { bufnr = bufnr } > 0
end

---@return table<string, boolean>
local function enabled_lsp_configs()
  local enabled = rawget(lsp, '_enabled_configs')
  if type(enabled) == 'table' then
    return enabled
  end

  return {}
end

---@param bufnr integer
---@param position { line: integer, character: integer }
---@param encoding? string
---@return integer
local function line_byte_from_position(bufnr, position, encoding)
  -- Keep private Neovim LSP APIs behind a small shim so compatibility work stays
  -- localized if upstream moves these helpers again.
  local get_line_byte = util._get_line_byte_from_position
  assert(
    type(get_line_byte) == 'function',
    'Expected Neovim byte-column helper'
  )
  return get_line_byte(bufnr, position, encoding or 'utf-16')
end

local function compare_pos(a_row, a_col, b_row, b_col)
  if a_row ~= b_row then
    return a_row < b_row and -1 or 1
  end

  if a_col ~= b_col then
    return a_col < b_col and -1 or 1
  end

  return 0
end

---@return BeaconLruCache?
local function new_cache()
  if config.max_cache_entries <= 0 then
    return nil
  end

  return lru.new(config.max_cache_entries)
end

---@param buf_state BeaconBufferState
local function rebuild_cache(buf_state)
  local old_cache = buf_state.cache
  buf_state.cache = new_cache()

  if not old_cache or not buf_state.cache then
    return
  end

  ---@type BeaconLspEntry[]
  local entries = {}
  for _, entry in old_cache:pairs() do
    entries[#entries + 1] = entry
  end

  for index = #entries, 1, -1 do
    local entry = entries[index]
    buf_state.cache:set(entry.key, entry)
  end
end

---@param bufnr integer
---@return BeaconBufferState
local function get_buf_state(bufnr)
  ---@type BeaconBufferState?
  local buf_state = state.buffers[bufnr]
  if buf_state then
    return buf_state
  end

  ---@type BeaconBufferState
  buf_state = {
    attach_wait_until = uv.now() + config.lsp_attach_timeout_ms,
    -- Bumps whenever server-side highlight semantics may have changed.
    server_tick = 0,
    active = nil,
    pending = nil,
    cache = new_cache(),
    cache_stats = new_cache_stats(),
    client_latencies = {},
  }

  state.buffers[bufnr] = buf_state
  return buf_state
end

---@param winid integer
---@return BeaconWindowState
local function get_win_state(winid)
  ---@type BeaconWindowState?
  local win_state = state.windows[winid]
  if win_state then
    return win_state
  end

  ---@type BeaconWindowState
  win_state = {
    timer = nil,
    target = nil,
    match_id = nil,
    match_bufnr = nil,
    match_word = nil,
    match_changedtick = nil,
  }

  state.windows[winid] = win_state
  return win_state
end

local function clear_fallback_match(winid)
  local win_state = state.windows[winid]
  if not win_state or not win_state.match_id then
    return
  end

  if is_valid_win(winid) then
    pcall(fn.matchdelete, win_state.match_id, winid)
  end

  win_state.match_id = nil
  win_state.match_bufnr = nil
  win_state.match_word = nil
  win_state.match_changedtick = nil
end

local function clear_fallback_matches_for_buffer(bufnr)
  for winid, win_state in pairs(state.windows) do
    if win_state.match_bufnr == bufnr then
      clear_fallback_match(winid)
    end
  end
end

local function clear_lsp_highlights(bufnr)
  if is_valid_buf(bufnr) then
    api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)
  end
end

local function clear_active(bufnr)
  clear_lsp_highlights(bufnr)
  clear_fallback_matches_for_buffer(bufnr)

  local buf_state = state.buffers[bufnr]
  if buf_state then
    buf_state.active = nil
  end
end

local function cancel_pending(bufnr)
  local buf_state = state.buffers[bufnr]
  if not buf_state or not buf_state.pending then
    return
  end

  local pending = assert(buf_state.pending)
  buf_state.pending = nil

  local cancel = pending.cancel
  if cancel then
    pcall(cancel)
  end
end

local function clear_window_timer(winid)
  local win_state = state.windows[winid]
  if not win_state then
    return
  end

  if win_state.timer then
    stop_timer(win_state.timer)
    win_state.timer = nil
  end

  win_state.target = nil
end

---@param bufnr integer
local function clear_buffer_runtime(bufnr)
  cancel_pending(bufnr)
  clear_active(bufnr)
end

local function clear_window_timers_for_buffer(bufnr)
  for winid, win_state in pairs(state.windows) do
    if win_state.target and win_state.target.bufnr == bufnr then
      clear_window_timer(winid)
    elseif is_valid_win(winid) and api.nvim_win_get_buf(winid) == bufnr then
      clear_window_timer(winid)
    end
  end
end

local function clear_all_runtime_state()
  for winid in pairs(state.windows) do
    clear_window_timer(winid)
  end

  for bufnr in pairs(state.buffers) do
    cancel_pending(bufnr)
  end

  for bufnr, buf_state in pairs(state.buffers) do
    clear_lsp_highlights(bufnr)
    buf_state.active = nil
  end

  for winid in pairs(state.windows) do
    clear_fallback_match(winid)
  end
end

local function invalidate_buffer(bufnr)
  -- Buffer invalidation changes the target identity, so pending per-window
  -- timers must be drained before they can resolve stale pre-edit targets.
  clear_window_timers_for_buffer(bufnr)

  local buf_state = state.buffers[bufnr]
  if not buf_state then
    return
  end

  clear_buffer_runtime(bufnr)
  buf_state.cache = new_cache()
end

local function reset_attach_wait(bufnr)
  local buf_state = get_buf_state(bufnr)
  buf_state.attach_wait_until = uv.now() + config.lsp_attach_timeout_ms
end

local function current_server_tick(bufnr)
  return get_buf_state(bufnr).server_tick
end

local function bump_server_tick(bufnr)
  local buf_state = get_buf_state(bufnr)
  buf_state.server_tick = buf_state.server_tick + 1
  return buf_state.server_tick
end

---@param bufnr integer
---@param client_id integer
---@return integer
local function predicted_client_latency_ms(bufnr, client_id)
  local client_latency = get_buf_state(bufnr).client_latencies[client_id]
  if client_latency then
    return client_latency.latency_ms
  end

  return config.lsp_miss_delay_ms
end

---@param bufnr integer
---@param client_ids integer[]
---@param sample_ms integer
local function record_lsp_latency_sample(bufnr, client_ids, sample_ms)
  local buf_state = get_buf_state(bufnr)
  sample_ms = math.max(0, sample_ms)

  -- Keep a fixed-size recent sample window per buffer/client so predictions can
  -- adapt when server latency changes instead of averaging forever.
  for _, client_id in ipairs(client_ids) do
    local client_latency = buf_state.client_latencies[client_id]
    if not client_latency then
      buf_state.client_latencies[client_id] = {
        latency_ms = config.lsp_miss_delay_ms,
        recent_samples = {},
        sample_count = 0,
        next_sample_index = 1,
        sample_total = 0,
      }
      client_latency = buf_state.client_latencies[client_id]
    end

    if client_latency.sample_count < config.lsp_latency_samples then
      local index = client_latency.sample_count + 1
      client_latency.recent_samples[index] = sample_ms
      client_latency.sample_count = index
      client_latency.sample_total = client_latency.sample_total + sample_ms
    else
      local index = client_latency.next_sample_index
      local replaced = client_latency.recent_samples[index]
      client_latency.sample_total = client_latency.sample_total
        - replaced
        + sample_ms
      client_latency.recent_samples[index] = sample_ms
      client_latency.next_sample_index = (index % config.lsp_latency_samples)
        + 1
    end

    if client_latency.sample_count < config.lsp_latency_samples then
      client_latency.next_sample_index = client_latency.sample_count + 1
    elseif client_latency.next_sample_index > config.lsp_latency_samples then
      client_latency.next_sample_index = 1
    end

    client_latency.latency_ms = math.floor(
      (client_latency.sample_total / client_latency.sample_count) + 0.5
    )
  end
end

---@param bufnr integer
---@return integer
local function predicted_lsp_request_latency_ms(bufnr)
  local clients =
    lsp.get_clients { bufnr = bufnr, method = DOC_HIGHLIGHT_METHOD }
  if #clients == 0 then
    return config.lsp_miss_delay_ms
  end

  local predicted_ms = 0

  -- `buf_request_all()` can only render after the slowest highlight-capable
  -- client replies, so budget against the largest per-client estimate.
  for _, client in ipairs(clients) do
    predicted_ms =
      math.max(predicted_ms, predicted_client_latency_ms(bufnr, client.id))
  end

  return predicted_ms
end

---@param base_delay_ms integer
---@param bufnr integer
---@return integer
local function derived_lsp_miss_delay_ms(base_delay_ms, bufnr)
  if base_delay_ms <= 0 then
    return 0
  end

  return math.max(
    config.lsp_miss_delay_min_ms,
    base_delay_ms - predicted_lsp_request_latency_ms(bufnr)
  )
end

---@param bufnr integer
---@param client_id integer
---@return BeaconClientLatencyState?
local function get_recorded_client_latency(bufnr, client_id)
  local buf_state = state.buffers[bufnr]
  return buf_state and buf_state.client_latencies[client_id] or nil
end

---@param bufnr integer
---@return string
local function format_lsp_latency_prediction(bufnr)
  local clients =
    lsp.get_clients { bufnr = bufnr, method = DOC_HIGHLIGHT_METHOD }
  table.sort(clients, function(a, b)
    return a.id < b.id
  end)

  if #clients == 0 then
    return ('Beacon LSP latency prediction: buffer %d no highlight-capable LSP clients attached'):format(
      bufnr
    )
  end

  local predicted_ms = 0
  ---@type string[]
  local parts = {}

  for _, client in ipairs(clients) do
    local recorded = get_recorded_client_latency(bufnr, client.id)
    local latency_ms = recorded and recorded.latency_ms
      or config.lsp_miss_delay_ms
    local sample_text = recorded
        and ('%d/%d samples'):format(
          recorded.sample_count,
          config.lsp_latency_samples
        )
      or 'seed'
    local label = client.name
        and client.name ~= ''
        and ('%s (%d)'):format(client.name, client.id)
      or ('client %d'):format(client.id)

    predicted_ms = math.max(predicted_ms, latency_ms)
    parts[#parts + 1] = ('%s %dms (%s)'):format(label, latency_ms, sample_text)
  end

  return ('Beacon LSP latency prediction: buffer %d miss delay %dms (delay_ms=%d, predicted=%dms, min=%dms), clients: %s'):format(
    bufnr,
    derived_lsp_miss_delay_ms(config.delay_ms, bufnr),
    config.delay_ms,
    predicted_ms,
    config.lsp_miss_delay_min_ms,
    table.concat(parts, ', ')
  )
end

local function cleanup_buffer(bufnr)
  if not state.buffers[bufnr] then
    return
  end

  invalidate_buffer(bufnr)
  state.buffers[bufnr] = nil
end

local function cleanup_window(winid)
  local win_state = state.windows[winid]
  if not win_state then
    return
  end

  clear_fallback_match(winid)

  if win_state.timer then
    stop_timer(win_state.timer)
  end

  state.windows[winid] = nil
end

---@param buf_state BeaconBufferState
---@param entry BeaconLspEntry
local function cache_put(buf_state, entry)
  if not buf_state.cache then
    return
  end

  buf_state.cache:set(entry.key, entry)
end

---@param range BeaconRange
---@param row integer
---@param col integer
---@return boolean
local function range_contains(range, row, col)
  if row < range.start_row or row > range.end_row then
    return false
  end

  if row == range.start_row and col < range.start_col then
    return false
  end

  if row == range.end_row and col >= range.end_col then
    return false
  end

  return true
end

---@param ranges BeaconRange[]
---@param row integer
---@param col integer
---@return integer?
local function find_range_index(ranges, row, col)
  local low = 1
  local high = #ranges
  local last_start_index = nil

  while low <= high do
    local mid = math.floor((low + high) / 2)
    local range = ranges[mid]

    if compare_pos(range.start_row, range.start_col, row, col) <= 0 then
      last_start_index = mid
      low = mid + 1
    else
      high = mid - 1
    end
  end

  if not last_start_index then
    return
  end

  if
    compare_pos(
      ranges[last_start_index].max_end_row,
      ranges[last_start_index].max_end_col,
      row,
      col
    ) <= 0
  then
    return
  end

  local first_candidate = last_start_index
  low = 1
  high = last_start_index

  -- Ranges stay sorted by start position, but servers can still return nested or
  -- overlapping spans. Binary-search the smallest prefix whose max end reaches
  -- the cursor, then scan only that candidate suffix for the exact containing
  -- range.
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local range = ranges[mid]

    if compare_pos(range.max_end_row, range.max_end_col, row, col) > 0 then
      first_candidate = mid
      high = mid - 1
    else
      low = mid + 1
    end
  end

  for index = last_start_index, first_candidate, -1 do
    if range_contains(ranges[index], row, col) then
      return index
    end
  end
end

---@param forward boolean
---@param ranges BeaconRange[]
---@param row integer
---@param col integer
---@return integer?
local function find_adjacent_range_start_index(forward, ranges, row, col)
  local low = 1
  local high = #ranges
  local result = nil

  -- Navigation also works from the gaps between highlights, so use the sorted
  -- range starts to find the nearest span in the requested direction.
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local range = ranges[mid]

    if forward then
      if compare_pos(row, col, range.start_row, range.start_col) < 0 then
        result = mid
        high = mid - 1
      else
        low = mid + 1
      end
    else
      if compare_pos(range.start_row, range.start_col, row, col) < 0 then
        result = mid
        low = mid + 1
      else
        high = mid - 1
      end
    end
  end

  return result
end

---@param buf_state BeaconBufferState
---@param changedtick integer
---@param server_tick integer
---@param row integer
---@param col integer
---@param count_lookup boolean
---@return BeaconLspEntry?
local function find_cached_entry(
  buf_state,
  changedtick,
  server_tick,
  row,
  col,
  count_lookup
)
  if not buf_state.cache then
    return
  end

  local hit_key = nil

  -- Reuse the hottest matching LSP entry first, and only refresh recency after
  -- a real hit so misses stay cheap.
  for key, entry in buf_state.cache:pairs() do
    if
      entry.changedtick == changedtick
      and entry.server_tick == server_tick
    then
      if find_range_index(entry.ranges, row, col) then
        hit_key = key
        break
      end
    end
  end

  if hit_key then
    if count_lookup then
      record_cache_hit(buf_state)
    end
    return buf_state.cache:get(hit_key)
  end

  if count_lookup then
    record_cache_miss(buf_state)
  end
end

local WORD_LEFT_REGEX = vim.regex([[\k\+$]])
local WORD_RIGHT_REGEX = vim.regex([[^\k\+]])

---@param line string
---@param col integer
---@return BeaconWord?
local function word_under_cursor(line, col)
  -- Split at the cursor byte column, then stitch together the keyword suffix on
  -- the left with the keyword prefix on the right. If the right side does not
  -- start with a keyword char, the cursor is not on a keyword at all.
  local left = line:sub(1, col)
  local right = line:sub(col + 1)
  local right_start, right_end = WORD_RIGHT_REGEX:match_str(right)

  if right_start ~= 0 or not right_end then
    return nil
  end

  local left_start, left_end = WORD_LEFT_REGEX:match_str(left)
  local prefix = left_start and left:sub(left_start + 1, left_end) or ''
  local suffix = right:sub(right_start + 1, right_end)

  return {
    text = prefix .. suffix,
    start_col = left_start or col,
    end_col = col + right_end,
  }
end

---@param winid integer
---@return BeaconTarget?
local function get_target(winid)
  if not is_valid_win(winid) then
    return nil
  end

  local bufnr = api.nvim_win_get_buf(winid)
  if not is_valid_buf(bufnr) or not config.should_attach(bufnr) then
    return nil
  end

  local cursor = api.nvim_win_get_cursor(winid)
  local row = cursor[1] - 1
  local col = cursor[2]
  local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  local word = word_under_cursor(line, col)

  if not word or word.text == '' then
    return nil
  end

  local changedtick = api.nvim_buf_get_changedtick(bufnr)

  return {
    bufnr = bufnr,
    changedtick = changedtick,
    row = row,
    col = col,
    word = word.text,
    start_col = word.start_col,
    end_col = word.end_col,
    key = table.concat({
      bufnr,
      changedtick,
      row,
      word.start_col,
      word.end_col,
      word.text,
    }, ':'),
  }
end

local function filetype_has_enabled_lsp_config(bufnr)
  local filetype = vim.bo[bufnr].filetype
  if filetype == '' then
    return false
  end

  for name in pairs(enabled_lsp_configs()) do
    local lsp_config = lsp.config[name]
    if lsp_config then
      local filetypes = lsp_config.filetypes
      if filetypes == nil or vim.list_contains(filetypes, filetype) then
        return true
      end
    end
  end

  return false
end

local function remaining_attach_wait_ms(bufnr)
  if config.lsp_attach_timeout_ms <= 0 or supports_lsp(bufnr) then
    return 0
  end

  -- Once any client is attached, stop waiting. If it still cannot provide
  -- document highlights, fallback should happen immediately.
  if has_attached_lsp_client(bufnr) then
    return 0
  end

  if not filetype_has_enabled_lsp_config(bufnr) then
    return 0
  end

  local buf_state = get_buf_state(bufnr)
  return math.max(0, buf_state.attach_wait_until - uv.now())
end

---@type fun(winid: integer, target: BeaconTarget, delay_ms: integer)
local schedule_target

local function client_has_pending_progress(client)
  return client
    and client.progress
    and next(client.progress.pending or {}) ~= nil
end

local function buffer_has_pending_progress(bufnr)
  for _, client in
    ipairs(lsp.get_clients { bufnr = bufnr, method = DOC_HIGHLIGHT_METHOD })
  do
    if client_has_pending_progress(client) then
      return true
    end
  end

  return false
end

---@param word string
---@return string
local function fallback_pattern(word)
  return ([[\V\C\<%s\>]]):format(fn.escape(word, [[\]]))
end

---@param target BeaconTarget
---@param results table<integer, { result: BeaconDocumentHighlightItem[]? }>
---@return BeaconLspEntry
local function build_lsp_entry(target, results)
  local bufnr = target.bufnr
  ---@type BeaconRange[]
  local ranges = {}
  ---@type table<string, BeaconRange>
  local seen = {}

  for client_id, response in pairs(results or {}) do
    local result = response.result
    if result then
      local client = lsp.get_client_by_id(client_id)
      local encoding = client and client.offset_encoding or 'utf-16'

      for _, item in ipairs(result) do
        local range = item.range
        if not range then
          ---@cast item BeaconLspRange
          range = item
        end

        local start_col = line_byte_from_position(bufnr, range.start, encoding)
        local end_col = line_byte_from_position(bufnr, range['end'], encoding)
        local key = table.concat({
          range.start.line,
          start_col,
          range['end'].line,
          end_col,
        }, ':')

        -- Some servers can report the same span multiple times, especially
        -- through macro expansion. Merge those duplicates so navigation never
        -- gets stuck revisiting the same position.
        local existing = seen[key]
        if existing then
          existing.kind = math.max(existing.kind, item.kind or 1)
        else
          ---@type BeaconRange
          local entry = {
            start_row = range.start.line,
            start_col = start_col,
            end_row = range['end'].line,
            end_col = end_col,
            max_end_row = range['end'].line,
            max_end_col = end_col,
            kind = item.kind or 1,
          }

          seen[key] = entry
          ranges[#ranges + 1] = entry
        end
      end
    end
  end

  table.sort(ranges, function(a, b)
    local start_cmp =
      compare_pos(a.start_row, a.start_col, b.start_row, b.start_col)
    if start_cmp ~= 0 then
      return start_cmp < 0
    end

    return compare_pos(a.end_row, a.end_col, b.end_row, b.end_col) < 0
  end)

  local max_end_row = -1
  local max_end_col = -1
  for _, range in ipairs(ranges) do
    if
      compare_pos(max_end_row, max_end_col, range.end_row, range.end_col) < 0
    then
      max_end_row = range.end_row
      max_end_col = range.end_col
    end

    range.max_end_row = max_end_row
    range.max_end_col = max_end_col
  end

  return {
    key = target.key,
    bufnr = bufnr,
    changedtick = target.changedtick,
    server_tick = current_server_tick(bufnr),
    ranges = ranges,
  }
end

---@param kind integer
---@return string
local function highlight_group_for_kind(kind)
  if kind == 2 then
    return config.highlight_groups.read
  end

  if kind == 3 then
    return config.highlight_groups.write
  end

  return config.highlight_groups.text
end

---@param winid integer
---@param target BeaconTarget
local function apply_fallback(winid, target)
  if not is_valid_win(winid) then
    return
  end

  local win_state = get_win_state(winid)
  if
    win_state.match_id
    and win_state.match_bufnr == target.bufnr
    and win_state.match_word == target.word
    and win_state.match_changedtick == target.changedtick
  then
    return
  end

  clear_fallback_match(winid)

  local pattern = fallback_pattern(target.word)

  local ok, match_id = pcall(
    fn.matchadd,
    config.highlight_groups.fallback,
    pattern,
    config.fallback_priority,
    -1,
    { window = winid }
  )

  if ok then
    win_state.match_id = match_id
    win_state.match_bufnr = target.bufnr
    win_state.match_word = target.word
    win_state.match_changedtick = target.changedtick
  end
end

---@param entry BeaconLspEntry
local function render_entry(entry)
  local bufnr = entry.bufnr
  local buf_state = get_buf_state(bufnr)

  clear_fallback_matches_for_buffer(bufnr)
  clear_lsp_highlights(bufnr)

  for _, range in ipairs(entry.ranges) do
    api.nvim_buf_set_extmark(
      bufnr,
      NAMESPACE,
      range.start_row,
      range.start_col,
      {
        end_row = range.end_row,
        end_col = range.end_col,
        hl_group = highlight_group_for_kind(range.kind),
        priority = config.priority,
        strict = false,
      }
    )
  end

  buf_state.active = entry
end

---@param winid integer
---@param target? BeaconTarget
local function sync_fallback_for_window(winid, target)
  if not is_valid_win(winid) then
    return
  end

  local win_state = state.windows[winid]
  if not win_state or not win_state.match_id then
    return
  end

  target = target or get_target(winid)
  if
    not target
    or win_state.match_bufnr ~= target.bufnr
    or win_state.match_word ~= target.word
    or win_state.match_changedtick ~= target.changedtick
  then
    clear_fallback_match(winid)
  end
end

---@param target BeaconTarget
---@param count_cache_lookup? boolean
---@return BeaconLspEntry?
local function cached_entry_for_target(target, count_cache_lookup)
  local buf_state = get_buf_state(target.bufnr)
  return find_cached_entry(
    buf_state,
    target.changedtick,
    current_server_tick(target.bufnr),
    target.row,
    target.col,
    count_cache_lookup ~= false
  )
end

---@param winid integer
---@param target BeaconTarget
---@return boolean
local function should_keep_fallback(winid, target)
  local win_state = state.windows[winid]
  return win_state
      and win_state.match_id
      and win_state.match_bufnr == target.bufnr
      and win_state.match_word == target.word
      and win_state.match_changedtick == target.changedtick
    or false
end

---@param target BeaconTarget
---@return boolean
local function should_keep_active(target)
  local buf_state = state.buffers[target.bufnr]
  local active = buf_state and buf_state.active or nil

  if
    not active
    or active.changedtick ~= target.changedtick
    or active.server_tick ~= current_server_tick(target.bufnr)
  then
    return false
  end

  return find_range_index(active.ranges, target.row, target.col) ~= nil
end

-- Pure decision function: callers must supply a fresh `target` (the current
-- word under cursor) so the planner never recomputes it internally.
---@param winid integer
---@param target BeaconTarget
---@param opts? BeaconResolveOptions
---@return BeaconResolvePlan
local function plan_target_resolution(winid, target, opts)
  opts = opts or {}

  if not opts.force_lsp and should_keep_fallback(winid, target) then
    return { action = 'keep_fallback', target = target }
  end

  if should_keep_active(target) then
    return { action = 'keep_active', target = target }
  end

  if supports_lsp(target.bufnr) then
    if not opts.force_lsp then
      local entry = cached_entry_for_target(target, opts.count_cache_lookup)
      if entry then
        return {
          action = 'use_cache',
          target = target,
          entry = entry,
        }
      end
    end

    return { action = 'request_lsp', target = target }
  end

  local wait_ms = remaining_attach_wait_ms(target.bufnr)
  if wait_ms > 0 then
    return { action = 'wait', target = target, wait_ms = wait_ms }
  end

  return { action = 'fallback', target = target }
end

---@param winid integer
---@param target BeaconTarget
local function request_lsp_entry(winid, target)
  local bufnr = target.bufnr
  local buf_state = get_buf_state(bufnr)
  local clients =
    lsp.get_clients { bufnr = bufnr, method = DOC_HIGHLIGHT_METHOD }

  if #clients == 0 then
    return
  end

  cancel_pending(bufnr)

  state.request_seq = state.request_seq + 1
  local seq = state.request_seq
  ---@type integer[]
  local client_ids = {}
  for _, client in ipairs(clients) do
    client_ids[#client_ids + 1] = client.id
  end

  ---@type BeaconPendingRequest
  local pending = {
    seq = seq,
    server_tick = current_server_tick(bufnr),
    started_at_ms = uv.now(),
    client_ids = client_ids,
  }

  buf_state.pending = pending

  pending.cancel = lsp.buf_request_all(
    bufnr,
    DOC_HIGHLIGHT_METHOD,
    function(client)
      return util.make_position_params(winid, client.offset_encoding)
    end,
    function(results)
      local current_state = state.buffers[bufnr]
      local current_pending = current_state and current_state.pending or nil
      -- Ignore stale responses that raced with later attach/progress changes.
      if
        not current_pending
        or current_pending.seq ~= seq
        or current_pending.server_tick ~= current_server_tick(bufnr)
      then
        return
      end

      cancel_pending(bufnr)
      record_lsp_latency_sample(
        bufnr,
        pending.client_ids,
        uv.now() - pending.started_at_ms
      )

      local entry = build_lsp_entry(target, results)
      if #entry.ranges == 0 then
        return
      end

      cache_put(current_state, entry)

      if
        not is_valid_win(winid)
        or api.nvim_get_current_win() ~= winid
        or api.nvim_win_get_buf(winid) ~= bufnr
      then
        return
      end

      local cursor = api.nvim_win_get_cursor(winid)
      local range_index =
        find_range_index(entry.ranges, cursor[1] - 1, cursor[2])

      if range_index then
        render_entry(entry)
      end
    end
  )
end

---@param winid integer
---@param target BeaconTarget
---@param plan BeaconResolvePlan
---@param opts? BeaconPlanApplyOptions
local function apply_target_resolution(winid, target, plan, opts)
  opts = opts or {}
  local bufnr = target.bufnr

  if plan.action == 'keep_fallback' or plan.action == 'keep_active' then
    if opts.clear_timer_on_keep then
      clear_window_timer(winid)
    end
    return
  end

  if opts.delay_ms ~= nil then
    local win_state = get_win_state(winid)
    if win_state.target and win_state.target.key == target.key then
      return
    end

    -- Cache misses subtract the predicted LSP round-trip, but never below the
    -- configured floor so rapid cursor movement cannot trigger immediate
    -- request bursts.
    local delay_ms = assert(opts.delay_ms)
    if plan.action == 'request_lsp' then
      delay_ms = derived_lsp_miss_delay_ms(delay_ms, target.bufnr)
    end

    -- Cursor-driven debounce gates every new visible highlight state, while
    -- LSP misses rearm with their predicted request delay above.
    if opts.clear_active_before_schedule then
      clear_active(bufnr)
    end
    if opts.cancel_pending_before_schedule then
      cancel_pending(bufnr)
    end

    schedule_target(winid, target, delay_ms)
    return
  end

  if plan.action == 'use_cache' then
    if opts.record_cache_hit then
      record_cache_hit(get_buf_state(bufnr))
    end
    if opts.clear_timer_on_cache then
      clear_window_timer(winid)
    end
    if opts.cancel_pending_on_cache then
      cancel_pending(bufnr)
    end
    render_entry(assert(plan.entry))
    return
  end

  clear_active(bufnr)

  if plan.action == 'wait' then
    schedule_target(winid, target, assert(plan.wait_ms))
    return
  end

  if plan.action == 'fallback' then
    apply_fallback(winid, target)
    return
  end

  request_lsp_entry(winid, target)
end

---@param winid integer
---@param target BeaconTarget
---@param opts? BeaconResolveOptions
local function resolve_target(winid, target, opts)
  local plan = plan_target_resolution(winid, target, opts)
  apply_target_resolution(winid, target, plan, {
    cancel_pending_on_cache = true,
  })
end

---@param winid integer
---@param opts? BeaconCurrentTargetOptions
local function handle_current_target(winid, opts)
  opts = opts or {}

  if not is_valid_win(winid) then
    return
  end

  local bufnr = api.nvim_win_get_buf(winid)
  if not in_normal_mode() then
    clear_window_timer(winid)
    clear_buffer_runtime(bufnr)
    return
  end

  local target = get_target(winid)
  sync_fallback_for_window(winid, target)

  if not target then
    clear_window_timer(winid)
    clear_buffer_runtime(bufnr)
    return
  end

  if opts.delay_ms == nil then
    clear_window_timer(winid)
    cancel_pending(bufnr)
    resolve_target(winid, target, opts.resolve_opts)
    return
  end

  -- Cursor-driven and non-cursor refresh entry points share the same planner
  -- and action handler so keep/cache/schedule behavior cannot drift apart.
  local plan =
    plan_target_resolution(winid, target, { count_cache_lookup = false })
  apply_target_resolution(winid, target, plan, {
    delay_ms = opts.delay_ms,
    clear_timer_on_keep = true,
    clear_timer_on_cache = true,
    cancel_pending_on_cache = true,
    record_cache_hit = true,
    clear_active_before_schedule = true,
    cancel_pending_before_schedule = true,
  })
end

---@param winid integer
---@param target BeaconTarget
---@param delay_ms integer
schedule_target = function(winid, target, delay_ms)
  local win_state = get_win_state(winid)

  if win_state.target and win_state.target.key == target.key then
    return
  end

  clear_window_timer(winid)

  win_state = get_win_state(winid)
  win_state.target = target
  local timer = assert(uv.new_timer(), 'Must be able to create timer')
  win_state.timer = timer

  timer:start(
    delay_ms,
    0,
    vim.schedule_wrap(function()
      local current_win_state = state.windows[winid]
      if not current_win_state or not current_win_state.target then
        return
      end

      local scheduled_target = assert(current_win_state.target)
      clear_window_timer(winid)
      if not in_normal_mode() then
        clear_buffer_runtime(scheduled_target.bufnr)
        return
      end
      resolve_target(winid, scheduled_target)
    end)
  )
end

---@param opts? BeaconCurrentTargetOptions
local function refresh_current_window(opts)
  handle_current_target(api.nvim_get_current_win(), opts)
end

---@param bufnr integer
---@return integer?
local function current_window_for_buffer(bufnr)
  if not is_valid_buf(bufnr) or api.nvim_get_current_buf() ~= bufnr then
    return nil
  end

  local winid = api.nvim_get_current_win()
  if api.nvim_win_get_buf(winid) ~= bufnr then
    return nil
  end

  return winid
end

local function on_mode_changed()
  if in_normal_mode() then
    refresh_current_window { delay_ms = config.delay_ms }
    return
  end

  clear_all_runtime_state()
end

---@param bufnr integer
local function schedule_current_buffer_refresh(bufnr)
  vim.schedule(function()
    local winid = current_window_for_buffer(bufnr)
    if not winid then
      return
    end

    -- Non-cursor events like reload completion and normal-mode text changes can
    -- settle the final cursor target without a fresh `CursorMoved`. Re-read the
    -- current target on the next loop turn so highlights do not wait for a
    -- manual cursor nudge.
    handle_current_target(winid, { delay_ms = config.delay_ms })
  end)
end

---@param bufnr integer
---@param opts? BeaconResolveOptions
local function refresh_current_buffer(bufnr, opts)
  local winid = current_window_for_buffer(bufnr)
  if not winid then
    return
  end

  handle_current_target(winid, { resolve_opts = opts })
end

local function on_lsp_attach(event)
  local bufnr = event.buf
  if not config.should_attach(bufnr) then
    return
  end

  bump_server_tick(bufnr)

  if supports_lsp(bufnr) then
    refresh_current_buffer(bufnr, { force_lsp = true })
    return
  end

  refresh_current_buffer(bufnr)
end

local function on_lsp_detach(event)
  local bufnr = event.buf
  local buf_state = state.buffers[bufnr]

  bump_server_tick(bufnr)

  if supports_lsp(bufnr) then
    return
  end

  cancel_pending(bufnr)

  if buf_state and buf_state.active then
    clear_active(bufnr)
    if api.nvim_get_current_buf() == bufnr then
      refresh_current_window { delay_ms = 0 }
    end
  end
end

local function on_lsp_progress(event)
  local data = event.data or {}
  local client = data.client_id and lsp.get_client_by_id(data.client_id) or nil

  if not client then
    return
  end

  -- Some servers attach before indexing is finished. Refresh when the last
  -- pending progress item completes so highlights update as soon as the server
  -- is actually ready.
  for bufnr in pairs(client.attached_buffers or {}) do
    if
      config.should_attach(bufnr)
      and client:supports_method(DOC_HIGHLIGHT_METHOD, bufnr)
    then
      if not buffer_has_pending_progress(bufnr) then
        bump_server_tick(bufnr)
        refresh_current_buffer(bufnr, { force_lsp = true })
      end
    end
  end
end

local function add_current_location_to_jumplist()
  -- `m'` is the built-in way to create a jumplist entry without inventing our
  -- own navigation state.
  api.nvim_cmd({ cmd = 'normal', bang = true, args = { "m'" } }, {})
end

---@param target BeaconTarget
---@return fun(): boolean
local function fallback_backward_skip(target)
  return function()
    local cursor = api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    return row == target.row
      and col >= target.start_col
      and col < target.end_col
  end
end

---@param forward boolean
local function goto_reference(forward)
  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_get_current_buf()
  local target = get_target(winid)
  if not target then
    clear_active(bufnr)
    return
  end

  if not should_keep_active(target) then
    refresh_current_buffer(bufnr)
  end

  local buf_state = state.buffers[bufnr]
  local entry = buf_state and buf_state.active or nil

  if entry and #entry.ranges > 0 then
    local cursor = api.nvim_win_get_cursor(winid)
    local row = cursor[1] - 1
    local col = cursor[2]
    local current_index = find_range_index(entry.ranges, row, col)
    local next_index = nil

    if forward then
      if current_index then
        next_index = current_index + 1
      else
        next_index =
          find_adjacent_range_start_index(true, entry.ranges, row, col)
      end

      if not next_index or next_index > #entry.ranges then
        if not config.wrap_navigation then
          return
        end
        next_index = 1
      end
    else
      if current_index then
        next_index = current_index - 1
      else
        next_index =
          find_adjacent_range_start_index(false, entry.ranges, row, col)
      end

      if not next_index or next_index < 1 then
        if not config.wrap_navigation then
          return
        end
        next_index = #entry.ranges
      end
    end

    local range_target = entry.ranges[next_index]
    add_current_location_to_jumplist()
    api.nvim_win_set_cursor(
      winid,
      { range_target.start_row + 1, range_target.start_col }
    )
    return
  end

  local win_state = state.windows[winid]
  if
    not win_state
    or not win_state.match_id
    or win_state.match_bufnr ~= bufnr
  then
    return
  end

  if target.word ~= win_state.match_word then
    return
  end

  -- Fallback mode intentionally delegates stepping to Neovim's native search
  -- engine instead of maintaining our own fallback range index.
  local pattern = fallback_pattern(target.word)

  local flags
  if forward then
    flags = config.wrap_navigation and 'w' or 'W'
  else
    flags = config.wrap_navigation and 'bw' or 'bW'
  end

  local skip = forward and nil or fallback_backward_skip(target)
  local found
  if skip then
    found = fn.search(pattern, flags .. 'n', 0, 0, skip)
  else
    found = fn.search(pattern, flags .. 'n')
  end

  if found == 0 then
    return
  end

  add_current_location_to_jumplist()
  if skip then
    fn.search(pattern, flags, 0, 0, skip)
  else
    fn.search(pattern, flags)
  end
end

function M.next_reference()
  goto_reference(true)
end

function M.prev_reference()
  goto_reference(false)
end

function M.clear(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  clear_window_timers_for_buffer(bufnr)
  clear_buffer_runtime(bufnr)
end

local function define_highlights()
  api.nvim_set_hl(
    0,
    config.highlight_groups.text,
    { link = 'LspReferenceText', default = true }
  )
  api.nvim_set_hl(
    0,
    config.highlight_groups.read,
    { link = 'LspReferenceRead', default = true }
  )
  api.nvim_set_hl(
    0,
    config.highlight_groups.write,
    { link = 'LspReferenceWrite', default = true }
  )
  api.nvim_set_hl(
    0,
    config.highlight_groups.fallback,
    { link = 'Search', default = true }
  )
end

local function clear_installed_mappings()
  local mappings = state.mappings
  if mappings.next then
    local map = fn.maparg(mappings.next, 'n', false, true)
    if type(map) == 'table' and map.desc == 'Next document reference' then
      pcall(vim.keymap.del, 'n', mappings.next)
    end
  end

  if mappings.prev then
    local map = fn.maparg(mappings.prev, 'n', false, true)
    if type(map) == 'table' and map.desc == 'Previous document reference' then
      pcall(vim.keymap.del, 'n', mappings.prev)
    end
  end

  state.mappings = {}
end

local function define_mappings()
  clear_installed_mappings()
  local mappings = config.mappings or {}

  if mappings.next then
    vim.keymap.set(
      'n',
      mappings.next,
      M.next_reference,
      { desc = 'Next document reference' }
    )
    state.mappings.next = mappings.next
  end

  if mappings.prev then
    vim.keymap.set(
      'n',
      mappings.prev,
      M.prev_reference,
      { desc = 'Previous document reference' }
    )
    state.mappings.prev = mappings.prev
  end
end

local function define_commands()
  api.nvim_create_user_command('BeaconCacheHitRatio', function()
    if config.max_cache_entries <= 0 then
      api.nvim_echo(
        { { 'Beacon LRU cache hit ratio: disabled (max_cache_entries=0)' } },
        false,
        {}
      )
      return
    end

    local bufnr = api.nvim_get_current_buf()
    local buf_state = state.buffers[bufnr]
    local buffer_ratio = buf_state
        and format_cache_hit_ratio(buf_state.cache_stats)
      or 'no lookups yet'

    api.nvim_echo({
      {
        ('Beacon LRU cache hit ratio: buffer %d %s, total %s'):format(
          bufnr,
          buffer_ratio,
          format_cache_hit_ratio(state.cache_stats)
        ),
      },
    }, false, {})
  end, {
    desc = 'Show Beacon LRU cache hit ratio',
    force = true,
  })

  api.nvim_create_user_command('BeaconLspLatencyPrediction', function()
    local bufnr = api.nvim_get_current_buf()
    api.nvim_echo({
      { format_lsp_latency_prediction(bufnr) },
    }, false, {})
  end, {
    desc = 'Show Beacon LSP latency prediction',
    force = true,
  })
end

---@param opts? BeaconConfigOptions
---@return BeaconModule
function M.setup(opts)
  local merged =
    vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
  if not opts or opts.lsp_miss_delay_ms == nil then
    merged.lsp_miss_delay_ms = math.max(0, math.floor(merged.delay_ms / 2))
  end
  merged.lsp_miss_delay_ms = math.max(0, math.floor(merged.lsp_miss_delay_ms))
  merged.lsp_miss_delay_min_ms =
    math.max(0, math.floor(merged.lsp_miss_delay_min_ms))
  merged.lsp_latency_samples =
    math.max(1, math.floor(merged.lsp_latency_samples))
  config = merged
  define_highlights()
  reset_cache_stats(state.cache_stats)

  -- Drain all outstanding async work so stale timers and LSP responses from a
  -- previous configuration cycle never land on new state.
  clear_all_runtime_state()

  for _, buf_state in pairs(state.buffers) do
    rebuild_cache(buf_state)
    reset_cache_stats(buf_state.cache_stats)
  end

  if state.augroup then
    pcall(api.nvim_del_augroup_by_id, state.augroup)
  end

  state.augroup = api.nvim_create_augroup('Beacon', { clear = true })

  api.nvim_create_autocmd('CursorMoved', {
    group = state.augroup,
    callback = function()
      refresh_current_window { delay_ms = config.delay_ms }
    end,
  })

  api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
    group = state.augroup,
    callback = function()
      local winid = api.nvim_get_current_win()
      local bufnr = api.nvim_get_current_buf()
      sync_fallback_for_window(winid)
      if not is_valid_buf(bufnr) or not config.should_attach(bufnr) then
        return
      end

      get_buf_state(bufnr)
      refresh_current_window { delay_ms = config.delay_ms }
    end,
  })

  api.nvim_create_autocmd('ModeChanged', {
    group = state.augroup,
    callback = on_mode_changed,
  })

  api.nvim_create_autocmd('BufReadPost', {
    group = state.augroup,
    callback = function(event)
      if not is_valid_buf(event.buf) or not config.should_attach(event.buf) then
        return
      end

      schedule_current_buffer_refresh(event.buf)
    end,
  })

  api.nvim_create_autocmd('FileType', {
    group = state.augroup,
    callback = function(event)
      reset_attach_wait(event.buf)
      invalidate_buffer(event.buf)
    end,
  })

  api.nvim_create_autocmd('TextChanged', {
    group = state.augroup,
    callback = function(event)
      invalidate_buffer(event.buf)

      -- Normal-mode edits like `u` can restore the same target without moving
      -- the cursor, so re-arm the usual delayed resolution after invalidation.
      schedule_current_buffer_refresh(event.buf)
    end,
  })

  api.nvim_create_autocmd('TextChangedI', {
    group = state.augroup,
    callback = function(event)
      invalidate_buffer(event.buf)
    end,
  })

  api.nvim_create_autocmd('LspAttach', {
    group = state.augroup,
    callback = on_lsp_attach,
  })

  api.nvim_create_autocmd('LspDetach', {
    group = state.augroup,
    callback = on_lsp_detach,
  })

  api.nvim_create_autocmd('LspProgress', {
    group = state.augroup,
    pattern = 'end',
    callback = on_lsp_progress,
  })

  api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = state.augroup,
    callback = function(event)
      cleanup_buffer(event.buf)
    end,
  })

  api.nvim_create_autocmd('WinClosed', {
    group = state.augroup,
    callback = function(event)
      cleanup_window(tonumber(event.match))
    end,
  })

  define_mappings()
  define_commands()

  local current_buf = api.nvim_get_current_buf()
  if is_valid_buf(current_buf) and config.should_attach(current_buf) then
    get_buf_state(current_buf)
  end

  ---@cast M BeaconModule
  return M
end

---@cast M BeaconModule
return M
