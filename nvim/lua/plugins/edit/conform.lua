return {
  'stevearc/conform.nvim',
  keys = {
    {
      '<leader>f',
      mode = 'v',
      function()
        require('conform').format({ async = true }, function(err)
          if not err then
            local mode = vim.api.nvim_get_mode().mode
            if vim.startswith(string.lower(mode), 'v') then
              vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes('<Esc>', true, false, true),
                'n',
                true
              )
            end
          end
        end)
      end,
      desc = 'LSP range format',
    },
    {
      '<S-D-i>',
      mode = { 'n', 'i' },
      function()
        require('conform').format({ async = true })
      end,
      desc = 'LSP format current buffer',
    },
    {
      '<S-M-i>',
      mode = { 'n', 'i' },
      function()
        require('conform').format({ async = true })
      end,
      desc = 'LSP format current buffer',
    },
  },
  opts = {
    formatters_by_ft = {
      c = { 'clang-format' },
      python = { 'black' },
      lua = { 'stylua' },
    },
    default_format_opts = {
      lsp_format = 'fallback',
    },
  },
}
