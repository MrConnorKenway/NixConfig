---@type LazyPluginSpec
return {
  'folke/lazydev.nvim',
  ft = 'lua', -- only load on lua files
  opts = {
    library = {
      { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
    },
    enabled = function(root_dir)
      return not vim.uv.fs_stat(root_dir .. '/.luarc.json')
    end,
  },
}
