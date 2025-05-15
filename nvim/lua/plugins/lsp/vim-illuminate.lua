---@type LazyPluginSpec
return {
  'MrConnorKenway/vim-illuminate',
  event = 'LspAttach',
  config = function()
    require('illuminate').configure {
      modes_allowlist = { 'n' },
      providers = { 'lsp' },
    }
    require('illuminate.config').get_raw().large_file_cutoff = nil
  end,
}
