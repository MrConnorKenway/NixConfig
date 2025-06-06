---@type LazyPluginSpec
return {
  'rebelot/heirline.nvim',
  lazy = false,
  priority = 999,
  config = function()
    local shrun_find_pattern = '^shrun://%d+//'
    local shrun_match_pattern = shrun_find_pattern .. '(.*)'
    local conditions = require('heirline.conditions')
    local utils = require('heirline.utils')
    local function setup_colors()
      local theme_colors = require('color_abstract_layer').get_colors()
      local colors = {
        heirline_color_special = utils.get_highlight('Special').fg,
        heirline_color_cursor = utils.get_highlight('Cursor').fg,
        heirline_color_diag_warn = utils.get_highlight('DiagnosticWarn').fg,
        heirline_color_diag_error = utils.get_highlight('DiagnosticError').fg,
        heirline_color_diag_hint = utils.get_highlight('DiagnosticHint').fg,
        heirline_color_diag_info = utils.get_highlight('DiagnosticInfo').fg,
        heirline_color_git_del = utils.get_highlight('GitSignsDelete').fg,
        heirline_color_git_add = utils.get_highlight('GitSignsAdd').fg,
        heirline_color_git_change = utils.get_highlight('GitSignsChange').fg,
        heirline_color_git_branch = utils.get_highlight('Constant').fg,
        heirline_color_file_name = utils.get_highlight('Directory').fg,
        heirline_color_file_type = utils.get_highlight('Type').fg,
      }
      for k, v in pairs(theme_colors) do
        colors['heirline_color_' .. k] = v
      end
      return colors
    end
    --- Heirline's `update` does not support mixing User event and normal event,
    --- so we have to hack by notifying GitStatusUpdate event when normal event
    --- is triggered
    local git_status_update_event =
      { 'BufEnter', 'ModeChanged', 'TermLeave', 'TermClose' }
    vim.api.nvim_create_autocmd(git_status_update_event, {
      callback = function()
        if vim.b.gitsigns_status_dict then
          vim.api.nvim_exec_autocmds('User', { pattern = 'GitStatusUpdate' })
        end
      end,
    })

    require('heirline').load_colors(setup_colors())

    local leaving = false
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        leaving = true
      end,
    })

    vim.api.nvim_create_autocmd('ColorScheme', {
      callback = function()
        require('heirline.utils').on_colorscheme(setup_colors)
      end,
    })

    local ViMode = {
      init = function(self)
        self.bufnr = vim.api.nvim_get_current_buf()
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
          niI = 'INSERT',
          niR = 'REPLACE',
          niV = 'VISUAL',
          nt = 'TERM NORM',
          ntT = 'TERMINAL',
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
          ['r?'] = 'CONFIRM',
          ['!'] = '!',
          t = 'TERMINAL',
        },
        mode_bgs = {
          n = 'heirline_color_normal',
          i = 'heirline_color_insert',
          v = 'heirline_color_visual',
          V = 'heirline_color_visual',
          ['\22'] = 'heirline_color_visual',
          c = 'heirline_color_command',
          s = 'heirline_color_select',
          S = 'heirline_color_select',
          ['\19'] = 'heirline_color_select',
          R = 'heirline_color_replace',
          r = 'heirline_color_replace',
          ['!'] = 'heirline_color_replace',
          t = 'heirline_color_terminal',
        },
      },
      -- We can now access the value of mode() that, by now, would have been
      -- computed by `init()` and use it to index our strings dictionary.
      -- note how `static` fields become just regular attributes once the
      -- component is instantiated.
      -- To be extra meticulous, we can also add some vim statusline syntax to
      -- control the padding and make sure our string is always at least 2
      -- characters long. Plus a nice Icon.
      provider = function(self)
        return ' %2(' .. self.mode_names[vim.fn.mode(1)] .. '%) '
      end,
      -- Same goes for the highlight. Now the foreground will change according to the current mode.
      hl = function(self)
        local mode = vim.fn.mode(1):sub(1, 1) -- get only the first mode character
        return {
          fg = 'heirline_color_cursor',
          bg = self.mode_bgs[mode],
          bold = true,
        }
      end,
      update = {
        'ModeChanged',
        'BufWinEnter',
        callback = function(self)
          if not leaving then
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(self.bufnr) then
                --- FIXME: this API may change in the future.
                vim.api.nvim__redraw { buf = self.bufnr, statusline = true }
              end
            end)
          end
        end,
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
      hl = { bold = true },
    }

    local ScrollBar = {
      static = {
        sbar = { '🭶', '🭷', '🭸', '🭹', '🭺', '🭻' },
      },
      provider = function(self)
        local curr_line = vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.api.nvim_buf_line_count(0)
        local i = lines > 0
            and math.floor((curr_line - 1) / lines * #self.sbar) + 1
          or 1
        return string.rep(self.sbar[i], 2)
      end,
      hl = function()
        local mode = vim.fn.mode(1):sub(1, 1) -- get only the first mode character
        return {
          fg = ViMode.static.mode_bgs[mode],
          bg = 'heirline_color_scrollbar_bg',
        }
      end,
    }

    local Diagnostics = {
      condition = conditions.has_diagnostics,

      static = {
        error_icon = '  ',
        warn_icon = ' 󰔶 ',
        info_icon = '  ',
        hint_icon = '  ',
      },

      init = function(self)
        self.errors =
          #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
        self.warnings =
          #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
        self.hints =
          #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
        self.info =
          #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
      end,

      update = { 'DiagnosticChanged', 'BufEnter' },

      {
        provider = function(self)
          -- 0 is just another output, we can decide to print it or not!
          return self.errors > 0 and (self.error_icon .. self.errors)
        end,
        hl = { fg = 'heirline_color_diag_error' },
      },
      {
        provider = function(self)
          return self.warnings > 0 and (self.warn_icon .. self.warnings)
        end,
        hl = { fg = 'heirline_color_diag_warn' },
      },
      {
        provider = function(self)
          return self.info > 0 and (self.info_icon .. self.info)
        end,
        hl = { fg = 'heirline_color_diag_info' },
      },
      {
        provider = function(self)
          return self.hints > 0 and (self.hint_icon .. self.hints)
        end,
        hl = { fg = 'heirline_color_diag_hint' },
      },
    }

    local FileIcon = {
      init = function(self)
        local filename = self.filename
        local extension = vim.fn.fnamemodify(filename, ':e')
        self.icon, self.icon_color =
          require('nvim-web-devicons').get_icon_color(
            filename,
            extension,
            { default = true }
          )
      end,
      provider = function(self)
        return self.icon and (self.icon .. ' ')
      end,
      hl = function(self)
        return { fg = self.icon_color }
      end,
    }

    local FileName = {
      provider = function(self)
        -- first, trim the pattern relative to the current directory. For other
        -- options, see :h filename-modifers
        local filename = vim.fn.fnamemodify(self.filename, ':.')
        if filename == '' then
          return '[No Name]'
        end
        -- now, if the filename would occupy more than 35% of the available
        -- space, we trim the file path to its initials
        -- See Flexible Components section below for dynamic truncation
        if not conditions.width_percent_below(#filename, 0.35) then
          filename = vim.fn.pathshorten(filename)
        end
        return filename:gsub('%%', '%%%%') --- Escape '%' if filename has one
      end,
      hl = { fg = 'heirline_color_file_name' },
    }

    local FileFlags = {
      {
        condition = function()
          return vim.bo.modified
        end,
        provider = '[+]',
        hl = { fg = 'heirline_color_green' },
      },
      {
        condition = function()
          return not vim.bo.modifiable or vim.bo.readonly
        end,
        provider = ' ',
        hl = { fg = 'heirline_color_red' },
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
          return { fg = 'heirline_color_special', bold = true, force = true }
        end
      end,
    }

    local FileNameBlock = {
      init = function(self)
        self.filename = vim.api.nvim_buf_get_name(0)
      end,
    }

    FileNameBlock = utils.insert(
      FileNameBlock,
      FileIcon,
      utils.insert(FileNameModifer, FileName), -- a new table where FileName is a child of FileNameModifier
      FileFlags
    )

    local FileType = {
      provider = function()
        return string.upper(vim.bo.filetype)
      end,
      hl = { fg = 'heirline_color_file_type', bold = true },
    }

    --- Mappings from git root dir to its ahead/behind string
    local ahead_behind_str = {}
    --- Contains boolean of whether component of certain root is querying git.
    local querying = {}
    --- Contains boolean of whether target buffer is redrawing.
    local redrawing = {}

    local Git = {
      condition = conditions.is_git_repo,

      init = function(self)
        self.status_dict = vim.b.gitsigns_status_dict
        self.bufnr = vim.api.nvim_get_current_buf()
      end,

      update = {
        'User',
        pattern = {
          'GitSigns*',
          'Fugitive*',
          'GitStatusUpdate',
        },
        callback = function()
          local cache = require('gitsigns.cache').cache
          local wins = vim.api.nvim_tabpage_list_wins(0)
          for _, win in ipairs(wins) do
            local bufnr = vim.api.nvim_win_get_buf(win)
            if cache[bufnr] and not redrawing[bufnr] then
              redrawing[bufnr] = true
              vim.schedule(function()
                if vim.api.nvim_buf_is_valid(bufnr) then
                  vim.api.nvim__redraw { buf = bufnr, statusline = true }
                end
                redrawing[bufnr] = false
              end)
            end
          end
        end,
      },

      hl = { fg = 'heirline_color_git_branch' },

      {
        provider = function(self)
          local repo = vim.fs.basename(self.status_dict.root)
          local cwd = vim.fs.basename(vim.uv.cwd())
          return repo ~= cwd and ' ' .. repo .. ' '
        end,
        hl = { bold = true },
      },
      {
        provider = function(self)
          local head = self.status_dict.head
          return (head:match('^[0-9a-f]+$') and ' ' or ' ') .. head
        end,
        hl = { bold = true },
      },
      {
        provider = function(self)
          local count = self.status_dict.added or 0
          return count > 0 and ('  ' .. count)
        end,
        hl = { fg = 'heirline_color_git_add' },
      },
      {
        provider = function(self)
          local count = self.status_dict.removed or 0
          return count > 0 and ('  ' .. count)
        end,
        hl = { fg = 'heirline_color_git_del' },
      },
      {
        provider = function(self)
          local count = self.status_dict.changed or 0
          return count > 0 and ('  ' .. count)
        end,
        hl = { fg = 'heirline_color_git_change' },
      },
      {
        provider = function(self)
          local root = self.status_dict.root
          if not querying[root] then
            querying[root] = true
            vim.system({
              'git',
              '-C',
              root,
              'rev-list',
              '--count',
              '--left-right',
              '@...@{u}',
            }, { text = true }, function(obj)
              local str

              querying[root] = false

              if (not obj.stdout) or (obj.stderr and obj.stderr:len() > 0) then
                str = ''
              else
                local ahead, behind = obj.stdout:match('(%d+)\t(%d+)')
                if ahead and behind then
                  str = ' '
                  if behind ~= '0' then
                    str = str .. '⇣' .. behind
                  end
                  if ahead ~= '0' then
                    str = str .. '⇡' .. ahead
                  end
                  if str == ' ' then
                    str = ''
                  end
                else
                  error('Unexpected git output: ' .. obj.stdout)
                end
              end

              --- Redraw only if string has changed
              if ahead_behind_str[root] ~= str then
                ahead_behind_str[root] = str
                vim.schedule(function()
                  vim.api.nvim_exec_autocmds(
                    'User',
                    { pattern = 'GitStatusUpdate' }
                  )
                end)
              end
            end)
          end

          return ahead_behind_str[root]
        end,
      },
      {
        provider = ' %<',
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
      hl = { fg = 'heirline_color_file_name' },
    }

    local TerminalName = {
      -- we could add a condition to check that buftype == 'terminal'
      -- or we could do that later (see #conditional-statuslines below)
      provider = function()
        local buf_name = vim.api.nvim_buf_get_name(0)
        local match = buf_name:match('^term://.*//%d+:(.*)')
        if match then
          return ' ' .. match
        end

        match = buf_name:match(shrun_match_pattern)
        if match then
          return ' ' .. match
        end

        return ' '
      end,
      hl = { fg = 'heirline_color_file_name', bold = true },
    }

    local Align = { provider = '%=' }
    local Space = { provider = ' ' }

    local SpecialStatusline = {
      condition = function()
        return conditions.buffer_matches {
          buftype = { 'nofile', 'prompt', 'help', 'quickfix' },
          filetype = { '^git.*', 'fugitive' },
        }
      end,

      FileType,
      Space,
      HelpFileName,
      Align,
    }

    local SnacksExplorerStatusLine = {
      condition = function()
        return conditions.buffer_matches { filetype = { 'snacks_layout_box' } }
      end,
    }

    local TerminalStatusline = {
      condition = function()
        return conditions.buffer_matches { buftype = { 'terminal' } }
      end,

      -- Quickly add a condition to the ViMode to only show it when buffer is active!
      {
        condition = function()
          if conditions.is_not_active() then
            return false
          end

          local buf_name = vim.api.nvim_buf_get_name(0)
          if buf_name:find(shrun_find_pattern) then
            return not require('shrun').scrolling_task_output
          else
            return true
          end
        end,
        ViMode,
        Space,
      },
      TerminalName,
      {
        provider = ' %<',
      },
      Align,
    }

    local function ShrunTasksOfStatus(status)
      return {
        condition = function(self)
          return self.nr_tasks[status] > 0
        end,
        provider = function(self)
          return string.format(
            ' %s%d',
            self.symbols[status],
            self.nr_tasks[status]
          )
        end,
        hl = function()
          return { fg = utils.get_highlight('ShrunHighlightTask' .. status).fg }
        end,
      }
    end

    local ShrunStatus = {
      condition = function()
        return package.loaded.shrun
      end,
      init = function(self)
        self.nr_tasks = require('shrun').nr_tasks_by_status()
      end,
      static = {
        symbols = {
          ['CANCELED'] = ' ',
          ['FAILED'] = '󰅚 ',
          ['SUCCESS'] = '󰄴 ',
          ['RUNNING'] = '󰑮 ',
        },
      },

      ShrunTasksOfStatus('CANCELED'),
      ShrunTasksOfStatus('FAILED'),
      ShrunTasksOfStatus('SUCCESS'),
      ShrunTasksOfStatus('RUNNING'),
    }

    local LSPActive = {
      condition = conditions.lsp_attached,
      update = { 'LspAttach', 'LspDetach' },

      -- Or complicate things a bit and get the servers names
      provider = function()
        local names = {}
        for _, server in pairs(vim.lsp.get_clients { bufnr = 0 }) do
          table.insert(names, server.name)
        end
        return ' ' .. table.concat(names, ' ')
      end,
      hl = { fg = 'heirline_color_green', bold = true },
    }

    local DefaultStatusline = {
      ViMode,
      Space,
      FileNameBlock,
      Space,
      Git,
      Align,
      ShrunStatus,
      Diagnostics,
      Space,
      LSPActive,
      Space,
      Ruler,
      Space,
      ScrollBar,
    }

    local StatusBorder = {
      provider = function()
        return '  '
      end,
      hl = { bg = 'heirline_color_scrollbar_bg' },
    }

    local InactiveStatusline = {
      condition = conditions.is_not_active,
      StatusBorder,
      Space,
      {
        hl = { fg = 'heirline_color_inactive_fg', force = true },
        FileNameBlock,
        Space,
        Git,
        Align,
        Diagnostics,
        Space,
        LSPActive,
        Space,
        Ruler,
        Space,
      },
      StatusBorder,
    }

    local StatusLines = {
      hl = function()
        local inactive_hl = 'StatusLineNC'

        if conditions.is_active() then
          local buf_name = vim.api.nvim_buf_get_name(0)
          if
            buf_name:find(shrun_find_pattern)
            and require('shrun').scrolling_task_output
          then
            return inactive_hl
          else
            return {
              bg = 'heirline_color_active_bg',
              fg = 'heirline_color_default_active_fg',
            }
          end
        else
          return inactive_hl
        end
      end,

      -- the first statusline with no condition, or which condition returns true is used.
      -- think of it as a switch case with breaks to stop fallthrough.
      fallthrough = false,

      SnacksExplorerStatusLine,
      SpecialStatusline,
      TerminalStatusline,
      InactiveStatusline,
      DefaultStatusline,
    }

    require('heirline').setup { statusline = StatusLines }
  end,
}
