return {
  'MrConnorKenway/vim-illuminate',
  event = 'LspAttach',
  config = function()
    require('illuminate').configure {
      modes_allowlist = { 'n' },
      providers = { 'lsp' }
    }
  end
}
