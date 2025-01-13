return {
  'folke/noice.nvim',
  dependencies = { 'MunifTanjim/nui.nvim' },
  opts = {
    lsp = {
      progress = { enabled = false },
      hover = { enabled = false },
      signature = { enabled = false }
    }
  }
}
