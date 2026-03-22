---@type LazyPluginSpec
return {
  'beacon',
  dev = true,
  config = function()
    require('beacon').setup {
      mappings = {
        next = '<A-n>',
        prev = '<A-p>',
      },
    }
  end,
}
