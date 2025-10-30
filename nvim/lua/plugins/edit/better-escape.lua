---@type LazyPluginSpec
return {
  'max397574/better-escape.nvim',
  config = function()
    require('better_escape').setup {
      timeout = 100,
      default_mappings = false,
      mappings = {
        -- i for insert
        i = {
          j = {
            k = '<Esc>',
          },
        },
        v = {
          j = {
            k = '<Esc>',
          },
        },
        s = {
          j = {
            k = '<Esc>',
          },
        },
      },
    }
  end,
}
