M = {}

--- @param bufnr integer Buffer handle, or 0 for current buffer
--- @param start_line integer First line index
--- @param end_line integer Last line index, exclusive
--- @param strict boolean Whether out-of-bounds should be an error.
--- @param lines string[] Array of lines to use as replacement
function M.buf_set_lines(bufnr, start_line, end_line, strict, lines)
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, strict, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
end

function M.buf_set_text(bufnr, start_line, start_col, end_line, end_col, lines)
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_text(
    bufnr,
    start_line,
    start_col,
    end_line,
    end_col,
    lines
  )
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
end

---Convert path to URL-like encoding string
---@param str string
function M.percent_encode(str)
  return str:gsub('[/\\:*?"\'<>+ |%.%%]', function(char)
    return string.format('%%%02X', string.byte(char))
  end)
end

return M
