---@type snacks.win?
local term_win
local term_height = 16

local function create_snacks_terminal()
  term_win = Snacks.terminal.get(nil, {
    win = {
      on_close = function(self)
        term_height = vim.api.nvim_win_get_height(self.win)
        --- Due to https://github.com/folke/snacks.nvim/commit/51996dfeac5f09,
        --- snacks will execute `wincmd p` on terminal closure, which does not
        --- trigger 'WinEnter'. So refire 'WinEnter' here.
        vim.schedule(function()
          vim.api.nvim_exec_autocmds('WinEnter', {})
        end)
      end,
    },
  })
end

local function snacks_terminal_toggle()
  if not term_win or not term_win:buf_valid() then
    create_snacks_terminal()
    return
  end

  term_win:toggle()
end

local function snacks_terminal_toggle_or_focus()
  if not term_win or not term_win:buf_valid() then
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

--- Delete a buffer:
--- - either the current buffer if `buf` is not provided
--- - or the buffer `buf` if it is a number
--- - or every buffer for which `buf` returns true if it is a function
---@param opts? number|snacks.bufdelete.Opts
local function bufdelete(opts)
  opts = opts or {}
  opts = type(opts) == 'number' and { buf = opts } or opts
  opts = type(opts) == 'function' and { filter = opts } or opts
  ---@cast opts snacks.bufdelete.Opts

  if type(opts.filter) == 'function' then
    for _, b in ipairs(vim.tbl_filter(opts.filter, vim.api.nvim_list_bufs())) do
      if vim.bo[b].buflisted then
        bufdelete(
          vim.tbl_extend('force', {}, opts, { buf = b, filter = false })
        )
      end
    end
    return
  end

  local buf = opts.buf or 0
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf

  vim.api.nvim_buf_call(buf, function()
    if vim.bo.modified and not opts.force then
      local ok, choice = pcall(
        vim.fn.confirm,
        ('Save changes to %q?'):format(vim.fn.bufname()),
        '&Yes\n&No\n&Cancel'
      )
      if not ok or choice == 0 or choice == 3 then -- 0 for <Esc>/<C-c> and 3 for Cancel
        return
      end
      if choice == 1 then -- Yes
        vim.cmd.write()
      end
    end

    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.api.nvim_win_call(win, function()
        if
          not vim.api.nvim_win_is_valid(win)
          or vim.api.nvim_win_get_buf(win) ~= buf
        then
          return
        end
        -- Try using alternate buffer
        local alt = vim.fn.bufnr('#')
        if alt ~= buf and vim.fn.buflisted(alt) == 1 then
          vim.api.nvim_win_set_buf(win, alt)
          return
        end

        -- Try using previous buffer provided by vim-buffer-ring
        local has_previous = pcall(vim.cmd, 'BufferRingReverse')
        if has_previous and buf ~= vim.api.nvim_win_get_buf(win) then
          return
        end

        -- Create new listed buffer
        local new_buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_win_set_buf(win, new_buf)
      end)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.cmd, (opts.wipe and 'bwipeout! ' or 'bdelete! ') .. buf)
    end
  end)
end

---@type LazyPluginSpec
return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  keys = {
    {
      '<leader><leader>',
      function()
        Snacks.picker.pickers()
      end,
      desc = 'Show all snacks picker',
    },
    {
      '<leader>,',
      function()
        Snacks.picker.resume()
      end,
      desc = 'Resume last snacks picker',
    },
    {
      '<leader>f',
      function()
        Snacks.picker.explorer {
          hidden = true,
          ignored = true,
          follow = true,
          focus = 'input',
        }
      end,
      desc = 'Open snacks explorer',
    },
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
        Snacks.picker.smart()
      end,
      desc = 'Picker find files',
    },
    {
      '<M-o>',
      mode = { 'n', 't', 'i' },
      function()
        Snacks.picker.smart()
      end,
      desc = 'Picker find files',
    },
    {
      '<D-p>',
      mode = { 'n', 't', 'i' },
      function()
        Snacks.picker.buffers {
          matcher = { frecency = true },
          current = false,
        }
      end,
      desc = 'Picker switch buffers',
    },
    {
      '<leader>p',
      function()
        Snacks.picker.buffers {
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
        Snacks.picker.grep()
      end,
      desc = 'Picker live grep',
    },
    {
      '<S-M-f>',
      mode = { 'n', 't', 'i' },
      function()
        Snacks.picker.grep()
      end,
      desc = 'Picker live grep',
    },
    {
      '<D-t>',
      mode = { 'n', 'i' },
      function()
        Snacks.picker.lsp_workspace_symbols()
      end,
      desc = 'Picker find workspace symbols',
    },
    {
      '<M-t>',
      mode = { 'n', 'i' },
      function()
        Snacks.picker.lsp_workspace_symbols()
      end,
      desc = 'Picker find workspace symbols',
    },
    {
      '<leader>s',
      function()
        Snacks.picker.lsp_workspace_symbols()
      end,
      desc = 'Picker find workspace symbols',
    },
    {
      '<leader>h',
      function()
        Snacks.picker.command_history()
      end,
      desc = 'Picker find command history',
    },
    {
      '<leader>S',
      function()
        Snacks.picker.lsp_symbols()
      end,
      desc = 'Picker find document symbols',
    },
    {
      '<S-D-o>',
      function()
        Snacks.picker.lsp_symbols()
      end,
      desc = 'Picker find document symbols',
    },
    {
      '<S-M-o>',
      function()
        Snacks.picker.lsp_symbols()
      end,
      desc = 'Picker find document symbols',
    },
    {
      '<leader>r',
      function()
        Snacks.picker.lsp_references()
      end,
      desc = 'Go to references',
    },
    {
      'gd',
      function()
        Snacks.picker.lsp_definitions()
      end,
      desc = 'Go to definitions',
    },
    {
      'gy',
      function()
        Snacks.picker.lsp_type_definitions()
      end,
      desc = 'Go to type definitions',
    },
    {
      '<leader>z',
      function()
        -- Zen mode only shows statusline when laststatus equals 3
        vim.o.laststatus = 3
        Snacks.zen.zoom()
      end,
      desc = 'Toggle snacks zoom',
    },
    {
      '<D-f>',
      mode = { 'n', 'i' },
      function()
        Snacks.picker.lines()
      end,
      desc = 'Picker search current buffer',
    },
    {
      '<M-f>',
      mode = { 'n' },
      function()
        Snacks.picker.lines()
      end,
      desc = 'Picker search current buffer',
    },
    {
      'U',
      function()
        Snacks.picker.undo()
      end,
      desc = 'Picker search undo history',
    },
    {
      '<leader>n',
      function()
        Snacks.notifier.show_history()
      end,
      desc = 'Notification History',
    },
    {
      '<leader>c',
      bufdelete,
      desc = 'Close buffer',
    },
    {
      'gH',
      function()
        local git_root
        if vim.b.gitsigns_status_dict then
          git_root = vim.b.gitsigns_status_dict.root
        else
          git_root = vim.fs.root(vim.env.PWD, '.git')
        end
        if not git_root then
          return
        end
        ---@param opts snacks.picker.Config
        ---@type snacks.picker.finder
        local function git_commit_finder(opts, ctx)
          if ctx.filter.search == '' then
            return function() end
          end
          local args = {
            '--no-pager',
            '-C',
            git_root,
            'log',
            '-G',
            ctx.filter.search,
            '--reverse',
            '--pretty=format:%h %s (%ch)',
          }
          if opts['all_branch'] then
            table.insert(args, '--all')
          end
          local finder = require('snacks.picker.source.proc').proc({
            opts,
            {
              cmd = 'git',
              args = args,
              transform = function(item)
                local commit, msg, date =
                  item.text:match('^(%S+) (.*) %((.*)%)$')
                item.msg = msg
                item.cwd = git_root
                item.date = date
                item.commit = commit
                item.pattern = ctx.filter.search
              end,
              notify = false, --- Silently fail
            },
          }, ctx)

          return finder
        end

        Snacks.picker {
          supports_live = true,
          toggles = {
            all_branch = 'a',
            follow = false,
            hidden = false,
            ignored = false,
          },
          actions = {
            git_show = function(picker)
              local item = picker:current()
              if item then
                picker:close()
                vim.cmd('G show ' .. item.commit)
              end
            end,
          },
          win = {
            input = {
              keys = {
                ['<cr>'] = { 'git_show', mode = { 'n', 'i' } },
                ['<M-a>'] = { 'toggle_all_branch', mode = { 'n', 'i' } },
              },
            },
          },
          finder = git_commit_finder,
          title = 'Git Grep Commit',
          live = true,
          preview = function(ctx)
            local builtin = ctx.picker.opts.previewers.git.builtin
            local cmd = {
              'git',
              '-c',
              'delta.' .. vim.o.background .. '=true',
              'show',
              ctx.item.commit,
              '-G',
              ctx.item.pattern,
            }
            local pathspec = ctx.item.files or ctx.item.file
            pathspec = type(pathspec) == 'table' and pathspec or { pathspec }
            if #pathspec > 0 then
              cmd[#cmd + 1] = '--'
              vim.list_extend(cmd, pathspec)
            end
            if builtin then
              table.insert(cmd, 2, '--no-pager')
            end
            Snacks.picker.preview.cmd(
              cmd,
              ctx,
              { ft = builtin and 'git' or nil }
            )
          end,
          format = 'git_log',
        }
      end,
      desc = 'Perform regex search in all commits',
    },
    {
      'gh',
      function()
        ---@type table<string, integer>
        ---table that contains mapping from file name to bufnr attached by gitsigns
        local attached_bufnr = {}

        if package.loaded.gitsigns then
          for bufnr, cache in pairs(require('gitsigns.cache').cache) do
            local filename = cache.git_obj.relpath
            if filename then
              attached_bufnr[filename] = bufnr
            end
          end
        end

        ---@type snacks.picker.finder
        local function gitsigns_finder(opts, ctx)
          if opts['staged'] then
            return {}
          end
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
                    hunk_line = line,
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
          local args = {
            '--no-pager',
            'diff',
            '--no-color',
            '--no-ext-diff',
            '--submodule=diff',
          }
          if opts['staged'] then
            --- TODO: Currently we have to mix both staged hunks and unstaged
            --- hunks, because the line number output of `git diff --staged` is
            --- with respect to file that does not contain unstaged changes, not
            --- the working tree file.
            table.insert(args, 'HEAD')
          end
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
                in_hunk = false
                return
              end

              if not in_hunk then
                if diff_text:sub(1, 6) == '--- a/' then
                  return
                end

                if diff_text:sub(1, 6) == '+++ b/' then
                  file_name = diff_text:sub(7)
                  bufnr = attached_bufnr[file_name]
                  if bufnr then
                    use_gitsigns = true
                  else
                    use_gitsigns = false
                  end

                  return
                end
              end

              if use_gitsigns and not opts['staged'] then
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
                  hunk_line = diff_text,
                  file = file_name,
                  pos = { line_number, 0 },
                  buf = attached_bufnr[file_name],
                }
                return
              end

              if char == '+' then
                cb {
                  text = file_name .. diff_text,
                  hunk_line = diff_text,
                  file = file_name,
                  pos = { line_number, 0 },
                  buf = attached_bufnr[file_name],
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

        Snacks.picker {
          toggles = {
            staged = 's',
            follow = false,
            hidden = false,
            ignored = false,
          },
          win = {
            input = {
              keys = {
                ['<M-s>'] = { 'toggle_staged', mode = { 'n', 'i' } },
              },
            },
          },
          layout = {
            preset = 'vertical',
          },
          title = 'Git Hunks',
          finder = { git_diff_finder, gitsigns_finder },
          show_empty = true, --- So that we can toggle staged
          formatters = {
            file = {
              truncate = 20,
            },
          },
          format = function(item, picker)
            local ret = {}
            local line = item.hunk_line ---@type string

            vim.list_extend(ret, Snacks.picker.format.filename(item, picker))
            local offset =
              Snacks.picker.highlight.offset(ret, { char_idx = true })

            Snacks.picker.highlight.format(item, line:sub(2), ret)
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
  ---@type snacks.Config | {}
  opts = {
    win = {
      backdrop = false,
    },
    notifier = {
      enabled = true,
      top_down = false,
      timeout = 1000,
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
      ---@type snacks.picker.icons | {}
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
        height = function()
          return term_height
        end,
      },
    },
    zen = {
      enabled = true,
      win = {
        on_close = function()
          -- In WinLeave we turn cursorline off, so now turn it on
          vim.wo.cursorline = true
          -- Revert to default statusline layout
          vim.o.laststatus = 2
        end,
      },
    },
    explorer = {
      replace_netrw = true,
    },
  },
}
