---@type LazyPluginSpec
return {
  'rmagatti/auto-session',
  lazy = false,
  config = function()
    require('auto-session').setup {
      suppressed_dirs = { '~' },
      use_git_branch = true,
      session_lens = {
        load_on_setup = false
      }
    }

    vim.keymap.set('n', '<leader>j', '<cmd>SessionSearch<cr>', { desc = 'Session Search' })
  end
}
