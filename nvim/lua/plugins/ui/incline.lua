return {
  'b0o/incline.nvim',
  dependencies = { 'SmiteshP/nvim-navic', 'nvim-tree/nvim-web-devicons' },
  event = 'VeryLazy',
  config = function()
    local helpers = require 'incline.helpers'
    local navic = require 'nvim-navic'
    local devicons = require 'nvim-web-devicons'
    local type_hl = {
      File = 'Directory',
      Module = '@include',
      Namespace = '@namespace',
      Package = '@include',
      Class = '@structure',
      Method = '@method',
      Property = '@property',
      Field = '@field',
      Constructor = '@constructor',
      Enum = '@field',
      Interface = '@type',
      Function = '@function',
      Variable = '@variable',
      Constant = '@constant',
      String = '@string',
      Number = '@number',
      Boolean = '@boolean',
      Array = '@field',
      Object = '@type',
      Key = '@keyword',
      Null = '@comment',
      EnumMember = '@field',
      Struct = '@structure',
      Event = '@keyword',
      Operator = '@operator',
      TypeParameter = '@type',
    }

    require('incline').setup {
      window = {
        padding = 0,
        margin = { horizontal = 0, vertical = 1 },
      },
      hide = {
        cursorline = 'focused_win',
      },
      render = function(props)
        if props.focused then
          local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ':t')
          if filename == '' then
            filename = '[No Name]'
          end
          local extension = vim.fn.fnamemodify(filename, ':e')
          local ft_icon, ft_color = devicons.get_icon_color(filename, extension, { default = true })
          local modified = vim.bo[props.buf].modified
          local res = {
            ft_icon and { ' ', ft_icon, ' ', guibg = ft_color, guifg = helpers.contrast_color(ft_color) } or '',
            ' ',
            { filename, gui = modified and 'bold,italic' or 'bold' },
            guibg = require('catppuccin.palettes').get_palette().surface0
          }
          local len = 0
          for i, item in ipairs(navic.get_data(props.buf) or {}) do
            len = len + #item.icon + #item.name
            if len / vim.api.nvim_win_get_width(0) > 0.45 and i > 1 then
              table.insert(res, { { '  ..' } })
              break
            end
            table.insert(res, {
              { '  ', group = 'NavicSeparator' },
              { item.icon, group = type_hl[item.type] },
              { item.name, group = type_hl[item.type] }
            })
          end
          return res
        end
        return {}
      end,
    }

    vim.api.nvim_create_autocmd('ColorScheme', {
      callback = function()
        -- clear incline's highlight cache
        require('incline.highlight').clear()
      end
    })
  end
}
