return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  keys = {
    {
      '<D-o>',
      mode = { 'n', 't', 'i' },
      function()
        require('snacks.picker').files({ matcher = { frecency = true } })
      end,
      desc = 'Picker find files'
    },
    {
      '<D-p>',
      mode = { 'n', 't', 'i' },
      function()
        require('snacks.picker').buffers {
          matcher = { frecency = true },
          current = false
        }
      end,
      desc = 'Picker switch buffers'
    },
    {
      '<S-D-f>',
      mode = { 'n', 't', 'i' },
      function() require('snacks.picker').grep() end,
      desc = 'Picker live grep'
    },
    {
      '<S-M-f>',
      mode = { 'n', 't', 'i' },
      function() require('snacks.picker').grep() end,
      desc = 'Picker live grep'
    },
    {
      '<D-t>',
      mode = { 'n', 'i' },
      function() require('snacks.picker').lsp_workspace_symbols() end,
      desc = 'Picker find workspace symbols'
    },
    {
      '<leader>s',
      function() require('snacks.picker').lsp_workspace_symbols() end,
      desc = 'Picker find workspace symbols'
    },
    {
      '<leader>h',
      function() require('snacks.picker').command_history() end,
      desc = 'Picker find command history'
    },
    {
      '<leader>S',
      function() require('snacks.picker').lsp_symbols() end,
      desc = 'Picker find document symbols'
    },
    {
      '<S-D-o>',
      function() require('snacks.picker').lsp_symbols() end,
      desc = 'Picker find document symbols'
    },
    {
      '<leader>r',
      function() require('snacks.picker').lsp_references() end,
      desc = 'Go to references'
    },
    {
      'gd',
      function() require('snacks.picker').lsp_definitions() end,
      desc = 'Go to definitions'
    },
    {
      'gy',
      function() require('snacks.picker').lsp_type_definitions() end,
      desc = 'Go to type definitions'
    },
    {
      '<leader>z',
      function()
        require('snacks.picker').zoxide()
      end,
      desc = 'Find files from zoxide'
    },
    {
      '<D-f>',
      mode = { 'n', 'i' },
      function() require('snacks.picker').lines() end,
      desc = 'Picker search current buffer'
    },
    {
      '<M-f>',
      mode = { 'n' },
      function() require('snacks.picker').lines() end,
      desc = 'Picker search current buffer'
    },
    {
      '<leader>n',
      function() require('snacks.notifier').show_history() end,
      desc = 'Notification History'
    },
    {
      '<leader>c',
      function() require('snacks.bufdelete').delete() end,
      desc = 'Close buffer'
    },
    {
      'gh',
      function()
        ---@param opts snacks.picker.Config
        ---@type snacks.picker.finder
        local function git_hunks(opts, ctx)
          ---@type snacks.picker.finder.Item[]
          local items = {}

          for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(bufnr) then
              local file = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr), { _fast = true })
              ---@type Gitsigns.Hunk.Hunk_Public[] | nil
              local hunks = require('gitsigns').get_hunks(bufnr)
              if hunks then
                for _, hunk in ipairs(hunks) do
                  local line_number = hunk.added.start
                  if line_number == 0 then
                    line_number = 1
                  end

                  for _, line in ipairs(hunk.lines) do
                    items[#items + 1] = {
                      text = line,
                      item = { hunk_line = line },
                      buf = bufnr,
                      file = file,
                      pos = { line_number, 0 },
                      lang = vim.bo[bufnr].filetype
                    }
                    if line:sub(1, 1) == '+' then
                      line_number = line_number + 1
                    end
                  end
                end
              end
            end
          end
          return ctx.filter:filter(items)
        end

        require('snacks').picker {
          layout = {
            preset = 'ivy',
          },
          finder = git_hunks,
          formatters = {
            file = {
              truncate = 20
            }
          },
          format = function(item, picker)
            local ret = {}
            local line = item.item.hunk_line ---@type string
            local byte_cnt = 0
            local function count_digit(number)
              local cnt = 0
              while number > 0 do
                number = math.floor(number / 10)
                cnt = cnt + 1
              end
              return cnt
            end
            local line_count_digits = count_digit(vim.api.nvim_buf_line_count(item.buf))
            local row_number_digits = count_digit(item.pos[1])
            local align_char_count = line_count_digits - row_number_digits

            vim.list_extend(ret, require('snacks.picker.format').filename(item, picker))
            for _, v in ipairs(ret) do
              byte_cnt = byte_cnt + string.len(v[1])
            end
            -- align file name
            if align_char_count > 0 then
              ret[#ret + 1] = { string.rep(' ', align_char_count) }
              byte_cnt = byte_cnt + align_char_count
            end
            require('snacks.picker').highlight.format(item, line:sub(2), ret)
            local hl = line:sub(1, 1) == '+' and 'DiffAdd' or 'DiffDelete'
            ret[#ret + 1] = {
              -- nvim_buf_set_extmark col wants byte count, not actual char numbers
              col = byte_cnt - 2,
              hl_group = hl,
              hl_eol = true
            }
            return ret
          end
        }
      end,
      desc = 'Picker search git hunks in opened buffers'
    }
  },
  opts = {
    notifier = {
      enabled = true,
      top_down = false,
      timeout = 1000,
    },
    bufdelete = {
      enabled = true
    },
    picker = {
      enabled = true,
      win = {
        -- input window
        input = {
          keys = {
            ['<Esc>'] = { 'close', mode = { 'n', 'i' } },
            ['<C-w>'] = { '<c-s-w>', mode = { 'i' }, expr = true, desc = 'delete word' },
            ['<S-CR>'] = { { 'pick_win', 'jump' }, mode = { 'n', 'i' } },
            ['<C-Up>'] = { 'history_back', mode = { 'i', 'n' } },
            ['<C-Down>'] = { 'history_forward', mode = { 'i', 'n' } },
            ['<Tab>'] = { 'select_and_next', mode = { 'i', 'n' } },
            ['<S-Tab>'] = { 'select_and_prev', mode = { 'i', 'n' } },
            ['<Down>'] = { 'list_down', mode = { 'i', 'n' } },
            ['<Up>'] = { 'list_up', mode = { 'i', 'n' } },
            ['<c-n>'] = { 'list_down', mode = { 'i', 'n' } },
            ['<c-p>'] = { 'list_up', mode = { 'i', 'n' } },
            ['<c-u>'] = { 'preview_scroll_up', mode = { 'i', 'n' } },
            ['<c-f>'] = { 'list_scroll_down', mode = { 'i', 'n' } },
            ['<c-d>'] = { 'preview_scroll_down', mode = { 'i', 'n' } },
            ['<c-b>'] = { 'list_scroll_up', mode = { 'i', 'n' } },
            ['<c-a>'] = false
          },
          b = {
            minipairs_disable = true,
          },
        },
      },
      icons = {
        diagnostics = {
          Error = '',
          Warn  = '󰔶',
          Hint  = '',
          Info  = '',
        }
      }
    }
  }
}
