-- LRU cache is implemented using a doubly linked list and
-- a hash map. Hash Map maps a key to a corresponding tuple.
-- Doubly Linked List is used to store list of tuples
-- (`value`, `previous`, `next`, `key`, `size_in_bytes`).
-- `key` is needed in a tuple to be able to remove an element from
-- the hash map. Field `size_in_bytes` is optional and is used
-- if sizes in bytes are counted (and constrained) as well as
-- the number of elements.
--
-- Create an instance of LRU cache for 100 elements:
--
-- ```lua
-- lru = require 'lru'
-- cache = lru.new(100)
-- ```
--
-- Create an instance of LRU cache for 100 elements of
-- 1000 bytes totally:
--
-- ```lua
-- lru = require 'lru'
-- cache = lru.new(100, 1000)
-- ```
--
-- Methods:
--
--   * `cache:set(key, value, size_in_bytes)` add or update an
--     element. If `key` is not in `cache`, creates new element.
--     Otherwise, updates the value of the existing element.
--     In both cases, moves the element to the head of the queue.
--
--     If the cache was full, the tail of the queue is removed.
--     If the cache has the limit of bytes used by its elements,
--     it is enforced as well: the elements are removed until
--     enough space is freed. If the size of the element being
--     added or updated is greater than the limit, the error
--     is thrown. Argument `size_in_bytes` defaults to `#value`.
--
--     If `value` is `nil`, it doesn't occupy a slot.
--
--     Complexity:
--
--       * O(1) if cache doesn't have `size_in_bytes` limit,
--       * amortized O(1) if cache has `size_in_bytes` limit.
--
--   * `cache:get(key)` returns the value corresponding to the key.
--     If `key` is not in `cache`, returns `nil`.
--     Otherwise moves the element to the head of the queue.
--
--     Complexity: O(1).
--
--   * `cache:delete(key)` same as `cache:set(key, nil)`
--
--     Complexity: O(1).
--
--   * `cache:pairs()` returns key-value iterator. Example:
--
--     ```lua
--     for key, value in cache:pairs() do
--         ...
--     end
--
--     -- Lua >= 5.2
--     for key, value in pairs(cache) do
--         ...
--     end
--     ```
--
--     Complexity:
--
--       * O(1) to create an iterator,
--       * O(cache size) to visit all elements.

local lru = {}

function lru.new(max_size, max_bytes)
  assert(max_size >= 1, 'max_size must be >= 1')
  assert(not max_bytes or max_bytes >= 1, 'max_bytes must be >= 1')

  -- current size
  local size = 0
  local bytes_used = 0

  -- map is a hash map from keys to tuples
  -- tuple: value, prev, next, key
  -- prev and next are pointers to tuples
  local map = {}

  -- indices of tuple
  local VALUE = 1
  local PREV = 2
  local NEXT = 3
  local KEY = 4
  local BYTES = 5

  -- newest and oldest are ends of double-linked list
  local newest = nil -- first
  local oldest = nil -- last

  local removed_tuple -- created in del(), removed in set()

  -- remove a tuple from linked list
  local function cut(tuple)
    local tuple_prev = tuple[PREV]
    local tuple_next = tuple[NEXT]
    tuple[PREV] = nil
    tuple[NEXT] = nil
    if tuple_prev and tuple_next then
      tuple_prev[NEXT] = tuple_next
      tuple_next[PREV] = tuple_prev
    elseif tuple_prev then
      -- tuple is the oldest element
      tuple_prev[NEXT] = nil
      oldest = tuple_prev
    elseif tuple_next then
      -- tuple is the newest element
      tuple_next[PREV] = nil
      newest = tuple_next
    else
      -- tuple is the only element
      newest = nil
      oldest = nil
    end
  end

  -- insert a tuple to the newest end
  local function setNewest(tuple)
    if not newest then
      newest = tuple
      oldest = tuple
    else
      tuple[NEXT] = newest
      newest[PREV] = tuple
      newest = tuple
    end
  end

  local function del(key, tuple)
    map[key] = nil
    cut(tuple)
    size = size - 1
    bytes_used = bytes_used - (tuple[BYTES] or 0)
    removed_tuple = tuple
  end

  -- removes elemenets to provide enough memory
  -- returns last removed element or nil
  local function makeFreeSpace(bytes)
    while
      size + 1 > max_size
      or (max_bytes and bytes_used + bytes > max_bytes)
    do
      assert(oldest, 'not enough storage for cache')
      del(oldest[KEY], oldest)
    end
  end

  local function get(_, key)
    local tuple = map[key]
    if not tuple then
      return nil
    end
    cut(tuple)
    setNewest(tuple)
    return tuple[VALUE]
  end

  local function set(_, key, value, bytes)
    local tuple = map[key]
    if tuple then
      del(key, tuple)
    end
    if value ~= nil then
      -- the value is not removed
      bytes = max_bytes and (bytes or #value) or 0
      makeFreeSpace(bytes)
      local tuple1 = removed_tuple or {}
      map[key] = tuple1
      tuple1[VALUE] = value
      tuple1[KEY] = key
      tuple1[BYTES] = max_bytes and bytes
      size = size + 1
      bytes_used = bytes_used + bytes
      setNewest(tuple1)
    else
      assert(key ~= nil, 'Key may not be nil')
    end
    removed_tuple = nil
  end

  local function delete(_, key)
    return set(_, key, nil)
  end

  local function mynext(_, prev_key)
    local tuple
    if prev_key then
      tuple = map[prev_key][NEXT]
    else
      tuple = newest
    end
    if tuple then
      return tuple[KEY], tuple[VALUE]
    else
      return nil
    end
  end

  -- returns iterator for keys and values
  local function lru_pairs()
    return mynext, nil, nil
  end

  local mt = {
    __index = {
      get = get,
      set = set,
      delete = delete,
      pairs = lru_pairs,
    },
    __pairs = lru_pairs,
  }

  return setmetatable({}, mt)
end

return lru
