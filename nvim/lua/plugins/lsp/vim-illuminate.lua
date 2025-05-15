---@type LazyPluginSpec
return {
  'MrConnorKenway/vim-illuminate',
  event = 'LspAttach',
  config = function()
    require('illuminate').configure {
      modes_allowlist = { 'n' },
      providers = { 'lsp', 'regex' },
      should_enable = function(bufnr)
        return vim.bo[bufnr].buftype == ''
      end,
    }
    require('illuminate.config').get_raw().large_file_cutoff = nil
  end,
}
