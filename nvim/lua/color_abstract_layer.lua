---@class Colors
---@field normal string
---@field insert string
---@field visual string
---@field command string
---@field select string
---@field replace string
---@field terminal string
---@field inactive_fg string
---@field active_bg string
---@field default_active_fg string
---@field incline_bg string
---@field scrollbar_bg string
---@field green string
---@field red string

local M = {}

local scheme_colors = {
  catppuccin = function()
    local theme_colors = require('catppuccin.palettes').get_palette()
    ---@type Colors
    return {
      normal = theme_colors.lavender,
      insert = theme_colors.green,
      visual = theme_colors.flamingo,
      command = theme_colors.peach,
      select = theme_colors.mauve,
      replace = theme_colors.maroon,
      terminal = theme_colors.green,
      inactive_fg = theme_colors.surface1,
      default_active_fg = theme_colors.overlay1,
      active_bg = require('catppuccin.utils.colors').vary_color(
        { latte = theme_colors.crust },
        theme_colors.surface0
      ),
      incline_bg = theme_colors.surface0,
      scrollbar_bg = theme_colors.surface1,
      red = theme_colors.red,
      green = theme_colors.green,
    }
  end,
}

---@return Colors
function M.get_colors()
  local scheme_name = vim.g.colors_name
  if scheme_name:find('catppuccin') then
    scheme_name = 'catppuccin'
  end
  local get_colors = scheme_colors[scheme_name]
  if not get_colors then
    vim.notify(
      'Color scheme ' .. scheme_name .. ' not supported',
      vim.log.levels.ERROR
    )
    ---@type Colors
    return {
      normal = '',
      insert = '',
      visual = '',
      command = '',
      select = '',
      replace = '',
      terminal = '',
      inactive_fg = '',
      active_bg = '',
      incline_bg = '',
      scrollbar_bg = '',
      red = '',
      green = '',
    }
  end
  return get_colors()
end

return M
