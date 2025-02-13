---@type snacks.win?
local term_win
local prev_win = -1

local function create_snacks_terminal()
  term_win = require('snacks.terminal').get(nil, {
    win = {
      on_win = function()
        prev_win = vim.fn.win_getid(vim.fn.winnr('#'))
      end,
      on_close = function()
        if vim.api.nvim_win_is_valid(prev_win) then
          vim.api.nvim_set_current_win(prev_win)
        end
      end,
    },
  })
end

local function snacks_terminal_toggle()
  if not term_win then
    create_snacks_terminal()
    return
  end

  term_win:toggle()
end

local function snacks_terminal_toggle_or_focus()
  if not term_win then
    create_snacks_terminal()
    return
  end

  if term_win.closed then
    term_win:toggle()
    return
  end

  if vim.api.nvim_get_current_win() == term_win.win then
    term_win:hide()
  else
    vim.api.nvim_set_current_win(term_win.win)
  end
end

---@type LazyPluginSpec
return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  keys = {
    {
      '<D-j>',
      mode = { 'n', 'i', 't' },
      function()
        if package.loaded.shrun then
          require('shrun').hide_panel()
          vim.schedule(snacks_terminal_toggle)
        else
          snacks_terminal_toggle()
        end
      end,
      desc = 'Toggle terminal',
    },
    {
      '<C-`>',
      mode = { 'n', 'i', 't' },
      function()
        if package.loaded.shrun then
          require('shrun').hide_panel()
          vim.schedule(snacks_terminal_toggle_or_focus)
        else
          snacks_terminal_toggle_or_focus()
        end
      end,
      desc = 'Toggle terminal',
    },
    {
      '<D-o>',
      mode = { 'n', 't', 'i' },
      function()
        require('snacks.picker').smart()
      end,
      desc = 'Picker find files',
    },
    {
      '<M-o>',
      mode = { 'n', 't', 'i' },
      function()
        require('snacks.picker').smart()
      end,
      desc = 'Picker find files',
    },
    {
      '<D-p>',
      mode = { 'n', 't', 'i' },
      function()
        require('snacks.picker').buffers {
          matcher = { frecency = true },
          current = false,
        }
      end,
      desc = 'Picker switch buffers',
    },
    {
      '<leader>p',
      function()
        require('snacks.picker').buffers {
          matcher = { frecency = true },
          current = false,
        }
      end,
      desc = 'Picker switch buffers',
    },
    {
      '<S-D-f>',
      mode = { 'n', 't', 'i' },
      function()
        require('snacks.picker').grep()
      end,
      desc = 'Picker live grep',
    },
    {
      '<S-M-f>',
      mode = { 'n', 't', 'i' },
      function()
        require('snacks.picker').grep()
      end,
      desc = 'Picker live grep',
    },
    {
      '<D-t>',
      mode = { 'n', 'i' },
      function()
        require('snacks.picker').lsp_workspace_symbols()
      end,
      desc = 'Picker find workspace symbols',
    },
    {
      '<M-t>',
      mode = { 'n', 'i' },
      function()
        require('snacks.picker').lsp_workspace_symbols()
      end,
      desc = 'Picker find workspace symbols',
    },
    {
      '<leader>s',
      function()
        require('snacks.picker').lsp_workspace_symbols()
      end,
      desc = 'Picker find workspace symbols',
    },
    {
      '<leader>h',
      function()
        require('snacks.picker').command_history()
      end,
      desc = 'Picker find command history',
    },
    {
      '<leader>S',
      function()
        require('snacks.picker').lsp_symbols()
      end,
      desc = 'Picker find document symbols',
    },
    {
      '<S-D-o>',
      function()
        require('snacks.picker').lsp_symbols()
      end,
      desc = 'Picker find document symbols',
    },
    {
      '<S-M-o>',
      function()
        require('snacks.picker').lsp_symbols()
      end,
      desc = 'Picker find document symbols',
    },
    {
      '<leader>r',
      function()
        require('snacks.picker').lsp_references()
      end,
      desc = 'Go to references',
    },
    {
      'gd',
      function()
        require('snacks.picker').lsp_definitions()
      end,
      desc = 'Go to definitions',
    },
    {
      'gy',
      function()
        require('snacks.picker').lsp_type_definitions()
      end,
      desc = 'Go to type definitions',
    },
    {
      '<leader>z',
      function()
        require('snacks.picker').zoxide()
      end,
      desc = 'Find files from zoxide',
    },
    {
      '<D-f>',
      mode = { 'n', 'i' },
      function()
        require('snacks.picker').lines()
      end,
      desc = 'Picker search current buffer',
    },
    {
      '<M-f>',
      mode = { 'n' },
      function()
        require('snacks.picker').lines()
      end,
      desc = 'Picker search current buffer',
    },
    {
      'U',
      function()
        require('snacks.picker').undo()
      end,
      desc = 'Picker search undo history',
    },
    {
      '<leader>n',
      function()
        require('snacks.notifier').show_history()
      end,
      desc = 'Notification History',
    },
    {
      '<leader>c',
      function()
        require('snacks.bufdelete').delete()
      end,
      desc = 'Close buffer',
    },
    {
      'gh',
      function()
        ---@type table<string, integer>
        ---table that contains mapping from file name to bufnr attached by gitsigns
        local attached_bufnr = {}
        local cwd = vim.fs.normalize(vim.uv.cwd() or '.')

        for bufnr, cache in pairs(require('gitsigns.cache').cache) do
          local filename = cache.file:gsub(cwd .. '/', '')
          attached_bufnr[filename] = bufnr
        end

        ---@type snacks.picker.finder
        local function gitsigns_finder(_, ctx)
          ---@type snacks.picker.finder.Item[]
          local items = {}

          for file, bufnr in pairs(attached_bufnr) do
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
                    text = file .. line,
                    item = { hunk_line = line },
                    buf = bufnr,
                    file = file,
                    pos = { line_number, 0 },
                    lang = vim.bo[bufnr].filetype,
                  }
                  if line:sub(1, 1) == '+' then
                    line_number = line_number + 1
                  end
                end
              end
            end
          end
          return ctx.filter:filter(items)
        end

        ---@param opts snacks.picker.Config
        ---@type snacks.picker.finder
        local function git_diff_finder(opts, ctx)
          local args = { '--no-pager', 'diff', '--no-color', '--no-ext-diff' }
          local finder = require('snacks.picker.source.proc').proc({
            opts,
            { cmd = 'git', args = args },
          }, ctx)

          ---@async
          ---@param cb async fun(item: snacks.picker.finder.Item)
          return function(cb)
            local file_name ---@type string
            local bufnr ---@type integer
            local in_hunk ---@type boolean
            local use_gitsigns ---@type boolean
            local line_number

            finder(function(proc_item)
              local diff_text = proc_item.text

              if diff_text:sub(1, 4) == 'diff' then
                file_name = diff_text:match('^diff .* a/.* b/(.*)$')
                bufnr = attached_bufnr[file_name]
                if bufnr then
                  use_gitsigns = true
                else
                  use_gitsigns = false
                  in_hunk = false
                end

                return
              end

              if use_gitsigns then
                return
              end

              if diff_text:sub(1, 1) == '@' then
                in_hunk = true
                local new_line_number =
                  diff_text:match('^@@ %-%d+,?%d* %+(%d+),%d+ @@')
                if new_line_number then
                  line_number = tonumber(new_line_number)
                  return
                else
                  error('Unexpected ' .. diff_text, vim.log.levels.ERROR)
                end
              end

              if not in_hunk then
                return
              end

              local char = diff_text:sub(1, 1)

              if char == '-' then
                cb {
                  text = file_name .. diff_text,
                  item = { hunk_line = diff_text },
                  file = file_name,
                  pos = { line_number, 0 },
                }
                return
              end

              if char == '+' then
                cb {
                  text = file_name .. diff_text,
                  item = { hunk_line = diff_text },
                  file = file_name,
                  pos = { line_number, 0 },
                }
                line_number = line_number + 1
                return
              end

              if char == ' ' then
                line_number = line_number + 1
                return
              end
            end)
          end
        end

        require('snacks').picker {
          layout = {
            preset = 'vertical',
          },
          finder = { git_diff_finder, gitsigns_finder },
          formatters = {
            file = {
              truncate = 20,
            },
          },
          format = function(item, picker)
            local ret = {}
            local line = item.item.hunk_line ---@type string

            vim.list_extend(
              ret,
              require('snacks.picker.format').filename(item, picker)
            )
            local offset = require('snacks.picker').highlight.offset(
              ret,
              { char_idx = true }
            )

            require('snacks.picker').highlight.format(item, line:sub(2), ret)
            local hl = line:sub(1, 1) == '+' and 'DiffAdd' or 'DiffDelete'
            ret[#ret + 1] =
              { string.rep(' ', vim.o.columns - offset - line:len()) }
            ret[#ret + 1] = {
              col = 2,
              end_col = vim.o.columns,
              hl_group = hl,
              strict = false,
            }
            return ret
          end,
        }
      end,
      desc = 'Picker search git hunks in opened buffers',
    },
  },
  opts = {
    notifier = {
      enabled = true,
      top_down = false,
      timeout = 1000,
    },
    bufdelete = {
      enabled = true,
    },
    picker = {
      enabled = true,
      layout = {
        layout = {
          backdrop = false,
        },
      },
      win = {
        -- input window
        input = {
          keys = {
            ['<Esc>'] = { 'close', mode = { 'n', 'i' } },
            ['<c-k>'] = { 'history_back', mode = { 'i', 'n' } },
            ['<c-j>'] = { 'history_forward', mode = { 'i', 'n' } },
            ['<c-u>'] = { 'preview_scroll_up', mode = { 'i', 'n' } },
            ['<c-f>'] = { 'list_scroll_down', mode = { 'i', 'n' } },
            ['<c-d>'] = { 'preview_scroll_down', mode = { 'i', 'n' } },
            ['<c-b>'] = { 'list_scroll_up', mode = { 'i', 'n' } },
            ['<c-a>'] = false,
          },
        },
      },
      icons = {
        diagnostics = {
          Error = '',
          Warn = '󰔶',
          Hint = '',
          Info = '',
        },
      },
    },
    terminal = {
      enabled = true,
      win = {
        wo = {
          winbar = '',
        },
        height = 16,
      },
    },
  },
}
