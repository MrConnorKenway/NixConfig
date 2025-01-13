return {
  'neovim/nvim-lspconfig',
  config = function()
    vim.api.nvim_create_autocmd('LspAttach', {
      callback = function(event)
        vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, {
          border = 'rounded'
        })
        vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(vim.lsp.handlers.signature_help, {
          border = 'rounded'
        })

        vim.keymap.set('n', '<leader>i', function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
        end, { desc = 'Toggle LSP inlay hint' })
        vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, { desc = 'LSP Rename' })
        vim.keymap.set('n', 'g.', vim.lsp.buf.code_action, { desc = 'LSP code actions' })

        vim.diagnostic.config({
          signs = {
            text = {
              [vim.diagnostic.severity.ERROR] = '',
              [vim.diagnostic.severity.WARN] = '󰔶',
              [vim.diagnostic.severity.INFO] = '',
              [vim.diagnostic.severity.HINT] = '',
            }
          }
        })
      end
    })

    local lspconfig = require('lspconfig')
    lspconfig.clangd.setup {
      cmd = { 'clangd', '--header-insertion=never' }
    }
    lspconfig.nixd.setup {}
    lspconfig.lua_ls.setup {}
    lspconfig.basedpyright.setup {}
  end
}
