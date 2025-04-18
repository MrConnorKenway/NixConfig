---@type LazyPluginSpec
return {
  'shrun',
  dev = true,
  config = function()
    require('shrun').setup()
  end,
  cmd = { 'ListTask', 'Task' },
  keys = {
    {
      '<D-r>',
      mode = { 'n', 'i', 't' },
      function()
        require('shrun').toggle_panel()
      end,
      desc = 'Toggle shrun task panel',
    },
    {
      '<M-r>',
      mode = { 'n', 'i', 't' },
      function()
        require('shrun').toggle_panel()
      end,
      desc = 'Toggle shrun task panel',
    },
    {
      '<S-D-r>',
      mode = { 'n', 'i', 't' },
      function()
        require('shrun').task_picker()
      end,
      desc = 'Toggle shrun task picker',
    },
    {
      '<S-M-r>',
      mode = { 'n', 'i', 't' },
      function()
        require('shrun').task_picker()
      end,
      desc = 'Toggle shrun task picker',
    },
    {
      'gu',
      function()
        require('shrun').restart_task_from_cmd('git push')
      end,
      desc = 'Git push',
    },
    {
      '``',
      function()
        require('shrun').launch_shell()
      end,
      desc = 'Open shrun shell',
    },
  },
  dependencies = {
    {
      'folke/snacks.nvim',
      'rebelot/heirline.nvim',
    },
  },
}
