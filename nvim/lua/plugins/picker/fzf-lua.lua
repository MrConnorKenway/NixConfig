return {
  'ibhagwan/fzf-lua',
  keys = {
    { '<leader>o', function() require('fzf-lua').files() end,   desc = 'FzfLua find files' },
    {
      '<D-o>',
      mode = { 'n', 't', 'i' },
      function() require('fzf-lua').files() end,
      desc = 'FzfLua find files'
    },
    {
      '<leader>O',
      function() require('fzf-lua').files { cwd = vim.fn.expand('%:h') } end,
      desc = 'FzfLua find files in directory of current buffer'
    },
    { '<leader>p', function() require('fzf-lua').buffers() end, desc = 'FzfLua switch buffers' },
    {
      '<D-p>',
      mode = { 'n', 't', 'i' },
      function() require('fzf-lua').buffers() end,
      desc = 'FzfLua switch buffers'
    },
    {
      '<leader>fg',
      function()
        require('fzf-lua').live_grep_native()
      end,
      desc = 'FzfLua live grep'
    },
    {
      '<S-D-f>',
      mode = { 'n', 't', 'i' },
      function() require('fzf-lua').live_grep_native() end,
      desc = 'FzfLua live grep'
    },
    {
      '<S-M-f>',
      mode = { 'n', 't', 'i' },
      function() require('fzf-lua').live_grep_native() end,
      desc = 'FzfLua live grep'
    },
    {
      '<D-f>',
      mode = { 'n', 'i' },
      function() require('fzf-lua').lgrep_curbuf() end,
      desc = 'FzfLua regex search current buffer'
    },
    {
      '<M-f>',
      mode = { 'n' },
      function() require('fzf-lua').lgrep_curbuf() end,
      desc = 'FzfLua regex search current buffer'
    },
    {
      '<leader>h',
      function() require('fzf-lua').command_history() end,
      desc =
      'FzfLua find command history'
    },
    {
      '<D-t>',
      mode = { 'n', 'i' },
      function() require('fzf-lua').lsp_live_workspace_symbols() end,
      desc = 'FzfLua find workspace symbols'
    },
    {
      '<leader>s',
      function() require('fzf-lua').lsp_live_workspace_symbols() end,
      desc = 'FzfLua find workspace symbols'
    },
    {
      'gh',
      function()
        local M = {}

        M.toggle_regex = function(_, opts)
          opts.__ACT_TO {
            resume = true,
          }
        end

        local fzf_lua = require('fzf-lua')
        local common_opts = {
          winopts = { title = ' Git Hunks ', title_pos = 'center' },
          actions = fzf_lua.defaults.actions.files,
          file_icons = true,
          color_icons = true,
          previewer = 'bat_native',
          field_index_expr = '{1}',
          line_field_index = '{2}',
          multiprocess = true,
          fzf_opts = {
            ["--multi"] = true
          }
        }
        common_opts.actions['ctrl-g'] = { fn = M.toggle_regex, noclose = true }

        local fn_transform = function(x)
          return fzf_lua.make_entry.file(x, common_opts)
        end

        local check_pattern = function(pattern, line)
          if not pattern then
            return true
          end

          local ok, ret = pcall(string.match, line, pattern)
          if ok and ret then
            return true
          end

          return false
        end

        -- diffn parses git diff and produces line number for each hunk
        local diffn = function(fzf_cb, live_query)
          local diff_text = vim.fn.system('git diff')
          local file_name = nil
          local line_number = nil
          local counter = 0

          for line in diff_text:gmatch('([^\n]+)') do
            if counter < 3 then
              counter = counter + 1
              goto continue
            end

            if counter == 3 then
              -- +++ b/
              file_name = line:match('^%+%+%+ b/(.*)')
              counter = counter + 1
              goto continue
            end

            local char = line:sub(1, 1)

            if char == '-' then
              if check_pattern(live_query, line) then
                fzf_cb(fn_transform(file_name) .. ':' .. line_number .. ':' .. ' \27[31m' .. line .. '\27[m')
              end
              goto continue
            end

            if char == '+' then
              if check_pattern(live_query, line) then
                fzf_cb(fn_transform(file_name) .. ':' .. line_number .. ':' .. ' \27[32m' .. line .. '\27[m')
              end
              line_number = line_number + 1
              goto continue
            end

            if char == ' ' then
              line_number = line_number + 1
              goto continue
            end

            local new_line_number = line:match('^@@ %-%d+,%d+ %+(%d+),%d+ @@')
            if new_line_number then
              line_number = new_line_number
              goto continue
            end

            counter = 1
            ::continue::
          end

          fzf_cb()
        end

        M.fuzzy_hunks = function(opts)
          opts = opts or {}
          opts = vim.tbl_deep_extend('keep', opts, common_opts)
          opts.__ACT_TO = M.lgrep_hunks
          opts.prompt = 'fuzzy> '
          opts = require('fzf-lua.config').normalize_opts(opts, {}, "hunk")

          fzf_lua.fzf_exec(function(fzf_cb)
            diffn(fzf_cb)
          end, opts)
        end

        M.lgrep_hunks = function(opts)
          opts = opts or {}

          opts = vim.tbl_deep_extend('keep', opts, common_opts)
          opts.__ACT_TO = M.fuzzy_hunks
          opts.prompt = 'lgrep> '
          opts.exec_empty_query = true
          opts = require('fzf-lua.config').normalize_opts(opts, {}, "hunk")

          fzf_lua.fzf_live(
            function(query)
              return function(fzf_cb)
                diffn(fzf_cb, query)
              end
            end,

            opts
          )
        end

        M.fuzzy_hunks()
      end
    }
  },
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    {
      'junegunn/fzf',
      lazy = true,
      build = './install --bin',
      enabled = function()
        return vim.fn.executable('fzf') == 0
      end
    }
  },
  opts = {
    'default-title',
    files = {
      git_icons = false
    },
    winopts = {
      treesitter = {
        enabled = true,
        fzf_colors = false
      },
      backdrop = 100,
      height = 0.85,
      width = 0.85,
      row = 0.40,
      preview = {
        default = vim.fn.executable('bat') == 0 and 'builtin' or 'bat_native',
        horizontal = 'right:52%',
        delay = 100
      }
    },
    manpages = { previewer = 'man_native' },
    previewers = {
      man_native = {
        cmd = 'bash -l -c "man %s | col -bx" | ' ..
            (vim.fn.executable('bat') == 0 and 'cat' or 'bat --color=always -p -l man')
      }
    },
    grep = {
      rg_opts = '--column --line-number --no-heading --no-ignore --color=always --smart-case --max-columns=4096 -e'
    },
    keymap = {
      builtin = {
        true,
        ['<C-u>'] = 'preview-half-page-up',
        ['<C-d>'] = 'preview-half-page-down',
        ['F9'] = 'toggle-preview'
      },
      fzf = {
        false,
        ['Ctrl-u'] = 'preview-half-page-up',
        ['Ctrl-d'] = 'preview-half-page-down',
        ['ctrl-a'] = 'beginning-of-line',
        ['ctrl-e'] = 'end-of-line',
        ['ctrl-f'] = 'half-page-down',
        ['ctrl-b'] = 'half-page-up',
        ['F9']     = 'toggle-preview'
      }
    }
  }
}
