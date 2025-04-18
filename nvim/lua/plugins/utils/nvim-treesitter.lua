--- Returns true if (row1, col1) is closer to the top left on screen than (row2, col2)
local function is_closer_to_the_top_left(r1, c1, r2, c2)
  if r1 < r2 then
    return true
  elseif r1 > r2 then
    return false
  else
    return c1 < c2
  end
end

vim.keymap.set('n', '[m', function()
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(win))
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if ok and parser then
    parser:parse(true)
    local nearest_prev_func_start_row = 0
    local nearest_prev_func_start_col = 0

    parser:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end

      local query = vim.treesitter.query.get(tree:lang(), 'textobjects')
      if not query then
        return
      end

      local func_id

      for i, capture_name in ipairs(query.captures) do
        if capture_name == 'function' then
          func_id = i
          break
        end
      end

      for capture_id, node, _ in query:iter_captures(tstree:root(), buf) do
        if capture_id == func_id then
          local func_start_row, func_start_col, func_end_row, func_end_col =
            node:range()
          func_start_row = func_start_row + 1
          func_end_row = func_end_row + 1
          if
            is_closer_to_the_top_left(
              nearest_prev_func_start_row,
              nearest_prev_func_start_col,
              func_start_row,
              func_start_col
            )
            and is_closer_to_the_top_left(
              func_end_row,
              func_end_col,
              cursor_row,
              cursor_col
            )
          then
            nearest_prev_func_start_row = func_start_row
            nearest_prev_func_start_col = func_start_col
          end
        end
      end

      if nearest_prev_func_start_row ~= 0 then
        vim.cmd("normal! m'") -- add to jump list
        vim.api.nvim_win_set_cursor(
          win,
          { nearest_prev_func_start_row, nearest_prev_func_start_col }
        )
      end
    end)
  end
end)

---@type LazyPluginSpec
return {
  'nvim-treesitter/nvim-treesitter',
  cmd = { 'TSInstall' },
  config = function()
    require('nvim-treesitter.install').ensure_installed {
      'python',
      'bash',
      'cpp',
    }
  end,
}
