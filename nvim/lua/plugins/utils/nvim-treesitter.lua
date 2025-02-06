return {
  'nvim-treesitter/nvim-treesitter',
  config = function()
    require('nvim-treesitter.configs').setup {
      modules = {},
      ignore_install = {},
      auto_install = false,
      sync_install = false,
      highlight = {
        enable = true,
      },
      indent = { enable = false },
      ensure_installed = {
        'c', 'lua', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline',
        'nix', 'asm', 'cpp', 'make', 'python', 'bash', 'rust', 'zig'
      }
    }
  end
}
