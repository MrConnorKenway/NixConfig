---@type LazyPluginSpec
return {
  'nvim-treesitter/nvim-treesitter',
  cmd = { 'TSInstall' },
  config = function()
    require('nvim-treesitter.install').ensure_installed {
      'python',
      'bash',
      'cpp',
    }
  end,
}
