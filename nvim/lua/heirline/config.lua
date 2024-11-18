return {
  'rebelot/heirline.nvim',
  lazy = false,
  priority = 999,
  dependencies = { 'linrongbin16/lsp-progress.nvim', 'SmiteshP/nvim-navic' },
  config = function()
    local conditions = require('heirline.conditions')
    local utils = require('heirline.utils')
    local theme_colors = require('catppuccin.palettes').get_palette()
    local colors = {
      bright_bg = utils.get_highlight('Folded').bg,
      bright_fg = utils.get_highlight('Folded').fg,
      red = utils.get_highlight('DiagnosticError').fg,
      blue = utils.get_highlight('Function').fg,
      orange = utils.get_highlight('Constant').fg,
      purple = utils.get_highlight('Statement').fg,
      cyan = utils.get_highlight('Special').fg,
      diag_warn = utils.get_highlight('DiagnosticWarn').fg,
      diag_error = utils.get_highlight('DiagnosticError').fg,
      diag_hint = utils.get_highlight('DiagnosticHint').fg,
      diag_info = utils.get_highlight('DiagnosticInfo').fg,
      git_del = utils.get_highlight('GitSignsDelete').fg,
      git_add = utils.get_highlight('GitSignsAdd').fg,
      git_change = utils.get_highlight('GitSignsChange').fg,
    }

    require('lsp-progress').setup {}

    require('heirline').load_colors(colors)

    local leaving = false
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        leaving = true
      end
    })

    local ViMode = {
      -- get vim current mode, this information will be required by the provider
      -- and the highlight functions, so we compute it only once per component
      -- evaluation and store it as a component attribute
      init = function(self)
        self.mode = vim.fn.mode(1) -- :h mode()
      end,
      -- Now we define some dictionaries to map the output of mode() to the
      -- corresponding string and color. We can put these into `static` to compute
      -- them at initialisation time.
      static = {
        mode_names = {
          n = 'NORMAL',
          no = 'OP PENDING',
          nov = 'OP PENDING',
          noV = 'OP PENDING',
          ['no\22'] = 'OP PENDING',
          niI = 'Ni',
          niR = 'Nr',
          niV = 'Nv',
          nt = 'TERM NORM',
          v = 'VISUAL',
          vs = 'Vs',
          V = 'VIS LINE',
          Vs = 'Vs',
          ['\22'] = 'VIS BLOCK',
          ['\22s'] = 'VIS BLOCK',
          s = 'SELECT',
          S = 'SEL LINE',
          ['\19'] = 'SEL BLOCK',
          i = 'INSERT',
          ic = 'Ic',
          ix = 'Ix',
          R = 'REPLACE',
          Rc = 'Rc',
          Rx = 'Rx',
          Rv = 'Rv',
          Rvc = 'Rv',
          Rvx = 'Rv',
          c = 'COMMAND',
          cv = 'Ex',
          r = '...',
          rm = 'M',
          ['r?'] = '?',
          ['!'] = '!',
          t = 'TERMINAL',
        },
        mode_bgs = {
          n = theme_colors.blue,
          i = theme_colors.green,
          v = theme_colors.mauve,
          V = theme_colors.mauve,
          ['\22'] = theme_colors.mauve,
          c = theme_colors.peach,
          s = 'purple',
          S = 'purple',
          ['\19'] = 'purple',
          R = theme_colors.red,
          r = theme_colors.red,
          ['!'] = 'red',
          t = theme_colors.green,
        }
      },
      -- We can now access the value of mode() that, by now, would have been
      -- computed by `init()` and use it to index our strings dictionary.
      -- note how `static` fields become just regular attributes once the
      -- component is instantiated.
      -- To be extra meticulous, we can also add some vim statusline syntax to
      -- control the padding and make sure our string is always at least 2
      -- characters long. Plus a nice Icon.
      provider = function(self)
        return ' %2(' .. self.mode_names[self.mode] .. '%) '
      end,
      -- Same goes for the highlight. Now the foreground will change according to the current mode.
      hl = function(self)
        local mode = self.mode:sub(1, 1) -- get only the first mode character
        return { fg = theme_colors.base, bg = self.mode_bgs[mode], bold = true }
      end,
      -- Re-evaluate the component only on ModeChanged event
      -- Also allows the statusline to be re-evaluated when entering operator-pending mode
      update = {
        'ModeChanged',
        pattern = '*:*',
        callback = vim.schedule_wrap(function()
          if not leaving then
            vim.cmd('redrawstatus')
          end
        end),
      },
    }

    local Ruler = {
      -- :help 'statusline'
      -- ------------------
      -- %-2 : make item takes at least 2 cells and be left justified
      -- %l  : current line number
      -- %L  : number of lines in the buffer
      -- %c  : column number
      -- %V  : virtual column number as -{num}.  Not displayed if equal to '%c'.
      provider = '%l:%-3(%v%)',
      hl = { bold = true }
    }

    local ScrollBar = {
      static = {
        sbar = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' }
      },
      provider = function(self)
        local curr_line = vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.api.nvim_buf_line_count(0)
        local i = math.floor((curr_line - 1) / lines * #self.sbar) + 1
        return string.rep(self.sbar[i], 2)
      end,
      hl = function()
        local mode = vim.fn.mode(1):sub(1, 1) -- get only the first mode character
        return { fg = ViMode.static.mode_bgs[mode], bg = 'bright_bg' }
      end
    }

    local Diagnostics = {
      condition = conditions.has_diagnostics,

      static = {
        error_icon = '  ',
        warn_icon = '  ',
        info_icon = '  ',
        hint_icon = '  ',
      },

      init = function(self)
        self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
        self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
        self.hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
        self.info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
      end,

      update = { 'DiagnosticChanged', 'BufEnter' },

      {
        provider = function(self)
          -- 0 is just another output, we can decide to print it or not!
          return self.errors > 0 and (self.error_icon .. self.errors)
        end,
        hl = { fg = 'diag_error' },
      },
      {
        provider = function(self)
          return self.warnings > 0 and (self.warn_icon .. self.warnings)
        end,
        hl = { fg = 'diag_warn' },
      },
      {
        provider = function(self)
          return self.info > 0 and (self.info_icon .. self.info)
        end,
        hl = { fg = 'diag_info' },
      },
      {
        provider = function(self)
          return self.hints > 0 and (self.hint_icon .. self.hints)
        end,
        hl = { fg = 'diag_hint' },
      },
    }

    local FileIcon = {
      init = function(self)
        local filename = self.filename
        local extension = vim.fn.fnamemodify(filename, ':e')
        self.icon, self.icon_color = require('nvim-web-devicons').get_icon_color(filename, extension,
          { default = true })
      end,
      provider = function(self)
        return self.icon and (self.icon .. ' ')
      end,
      hl = function(self)
        return { fg = self.icon_color }
      end
    }

    local FileName = {
      provider = function(self)
        -- first, trim the pattern relative to the current directory. For other
        -- options, see :h filename-modifers
        local filename = vim.fn.fnamemodify(self.filename, ':.')
        if filename == '' then return '[No Name]' end
        -- now, if the filename would occupy more than 1/4th of the available
        -- space, we trim the file path to its initials
        -- See Flexible Components section below for dynamic truncation
        if not conditions.width_percent_below(#filename, 0.25) then
          filename = vim.fn.pathshorten(filename)
        end
        return filename
      end,
      hl = { fg = utils.get_highlight('Directory').fg },
    }

    local FileFlags = {
      {
        condition = function()
          return vim.bo.modified
        end,
        provider = '[+]',
        hl = { fg = theme_colors.green },
      },
      {
        condition = function()
          return not vim.bo.modifiable or vim.bo.readonly
        end,
        provider = ' ',
        hl = { fg = 'red' },
      },
    }

    -- Now, let's say that we want the filename color to change if the buffer is
    -- modified. Of course, we could do that directly using the FileName.hl field,
    -- but we'll see how easy it is to alter existing components using a 'modifier'
    -- component
    local FileNameModifer = {
      hl = function()
        if vim.bo.modified then
          -- use `force` because we need to override the child's hl foreground
          return { fg = 'cyan', bold = true, force = true }
        end
      end,
    }

    local FileNameBlock = {
      init = function(self)
        self.filename = vim.api.nvim_buf_get_name(0)
      end,
    }

    FileNameBlock = utils.insert(FileNameBlock,
      FileIcon,
      utils.insert(FileNameModifer, FileName), -- a new table where FileName is a child of FileNameModifier
      FileFlags,
      { provider = ' %<' }                     -- this means that the statusline is cut here when there's not enough space
    )

    local FileType = {
      provider = function()
        return string.upper(vim.bo.filetype)
      end,
      hl = { fg = utils.get_highlight('Type').fg, bold = true },
    }

    local Git = {
      condition = conditions.is_git_repo,

      init = function(self)
        self.status_dict = vim.b.gitsigns_status_dict
      end,

      hl = { fg = 'orange' },

      {
        provider = function(self)
          return ' ' .. self.status_dict.head
        end,
        hl = { bold = true }
      },
      {
        provider = function(self)
          local count = self.status_dict.added or 0
          return count > 0 and ('  ' .. count)
        end,
        hl = { fg = 'git_add' },
      },
      {
        provider = function(self)
          local count = self.status_dict.removed or 0
          return count > 0 and ('  ' .. count)
        end,
        hl = { fg = 'git_del' },
      },
      {
        provider = function(self)
          local count = self.status_dict.changed or 0
          return count > 0 and ('  ' .. count)
        end,
        hl = { fg = 'git_change' },
      },
    }

    local HelpFileName = {
      condition = function()
        return vim.bo.filetype == 'help'
      end,
      provider = function()
        local filename = vim.api.nvim_buf_get_name(0)
        return vim.fn.fnamemodify(filename, ':t')
      end,
      hl = { fg = colors.blue },
    }

    local TerminalName = {
      -- we could add a condition to check that buftype == 'terminal'
      -- or we could do that later (see #conditional-statuslines below)
      provider = function()
        local tname, _ = vim.api.nvim_buf_get_name(0):gsub('.*:', '')
        local idx = tname:match(';#toggleterm#(.*)')
        if idx ~= nil then
          tname = tname:gsub(';#.*', '')
          return string.format(' %s [%d]', tname, idx)
        else
          return ' ' .. tname
        end
      end,
      hl = { fg = colors.blue, bold = true },
    }

    local Align = { provider = '%=' }
    local Space = { provider = ' ' }
    local LongSpace = { provider = '  ' }

    local SpecialStatusline = {
      condition = function()
        return conditions.buffer_matches({
          buftype = { 'nofile', 'prompt', 'help', 'quickfix' },
          filetype = { '^git.*', 'fugitive' },
        })
      end,

      FileType,
      Space,
      HelpFileName,
      Align
    }

    local TerminalStatusline = {
      condition = function()
        return conditions.buffer_matches({ buftype = { 'terminal' } })
      end,

      -- Quickly add a condition to the ViMode to only show it when buffer is active!
      { condition = conditions.is_active, ViMode, Space },
      TerminalName,
      Align,
    }

    local LSPMessages = {
      provider = function() return require('lsp-progress').progress() end,
      update = {
        'User',
        pattern = 'LspProgressStatusUpdated',
        callback = vim.schedule_wrap(function()
          if not leaving then
            vim.cmd('redrawstatus')
          end
        end),
      },
      hl = { fg = theme_colors.green, bold = true },
    }

    local Navic = {
      condition = function() return require('nvim-navic').is_available() end,
      static = {
        -- create a type highlight map
        type_hl = {
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
        },
        -- bit operation dark magic, see below...
        enc = function(line, col, winnr)
          return bit.bor(bit.lshift(line, 16), bit.lshift(col, 6), winnr)
        end,
        -- line: 16 bit (65535); col: 10 bit (1023); winnr: 6 bit (63)
        dec = function(c)
          local line = bit.rshift(c, 16)
          local col = bit.band(bit.rshift(c, 6), 1023)
          local winnr = bit.band(c, 63)
          return line, col, winnr
        end
      },
      init = function(self)
        local data = require('nvim-navic').get_data() or {}
        local children = {}
        -- create a child for each level
        for i, d in ipairs(data) do
          -- encode line and column numbers into a single integer
          local child = {
            {
              provider = d.icon,
              hl = self.type_hl[d.type],
            },
            {
              -- escape `%`s (elixir) and buggy default separators
              provider = d.name:gsub('%%', '%%%%'):gsub('%s*->%s*', ''),
              -- highlight icon only or location name as well
              hl = self.type_hl[d.type],
            }
          }
          -- add a separator only if needed
          if #data > 1 and i < #data then
            table.insert(child, {
              provider = ' > ',
              hl = { fg = 'bright_fg' },
            })
          end
          table.insert(children, child)
        end
        -- instantiate the new child, overwriting the previous one
        self.child = self:new(children, 1)
      end,
      -- evaluate the children containing navic components
      provider = function(self)
        return self.child:eval()
      end,
    }

    local DefaultStatusline = {
      ViMode,
      Space,
      FileNameBlock,
      Space,
      Git,
      LongSpace,
      Navic,
      Align,
      Diagnostics,
      Space,
      LSPMessages,
      Space,
      Ruler,
      Space,
      ScrollBar
    }

    local StatusBorder = {
      provider = function()
        return '  '
      end,
      hl = { bg = 'bright_bg' }
    }

    local InactiveStatusline = {
      condition = conditions.is_not_active,
      StatusBorder,
      Space,
      {
        hl = { fg = 'bright_bg', force = true },
        FileNameBlock,
        Space,
        Git,
        LongSpace,
        Navic,
        Align,
        Diagnostics,
        Space,
        LSPMessages,
        Space,
        Ruler,
        Space
      },
      StatusBorder
    }

    local StatusLines = {
      hl = function()
        if conditions.is_active() then
          return { bg = theme_colors.surface0 }
        else
          return 'StatusLineNC'
        end
      end,

      -- the first statusline with no condition, or which condition returns true is used.
      -- think of it as a switch case with breaks to stop fallthrough.
      fallthrough = false,

      SpecialStatusline,
      TerminalStatusline,
      InactiveStatusline,
      DefaultStatusline,
    }

    require('heirline').setup({ statusline = StatusLines })
  end
}
