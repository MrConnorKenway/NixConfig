---@type LazyPluginSpec
return {
  'windwp/nvim-autopairs',
  event = 'InsertEnter',
  opts = {
    disable_filetype = { 'snacks_picker_input' },
  },
}
