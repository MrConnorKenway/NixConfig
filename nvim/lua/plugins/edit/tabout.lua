return {
  'abecodes/tabout.nvim',
  opts = {
    tabkey = '<Tab>',             -- key to trigger tabout, set to an empty string to disable
    backwards_tabkey = '<S-Tab>', -- key to trigger backwards tabout, set to an empty string to disable
    act_as_tab = true,            -- shift content if tab out is not possible
    act_as_shift_tab = false,     -- reverse shift content if tab out is not possible (if your keyboard/terminal supports <S-Tab>)
    default_tab = '<C-t>',        -- shift default action (only at the beginning of a line, otherwise <TAB> is used)
    default_shift_tab = '<C-d>',  -- reverse shift default action,
    enable_backwards = true,      -- well ...
    completion = false,           -- if the tabkey is used in a completion pum
    tabouts = {
      { open = "'", close = "'" },
      { open = '"', close = '"' },
      { open = '`', close = '`' },
      { open = '(', close = ')' },
      { open = '[', close = ']' },
      { open = '<', close = '>' },
      { open = '{', close = '}' }
    },
    ignore_beginning = false, -- only tabout if at beginning of configured tabout chars
    exclude = {}              -- tabout will ignore these filetypes
  },
  dependencies = {            -- These are optional
    'nvim-treesitter/nvim-treesitter'
  },
  opt = true, -- Set this to true if the plugin is optional
  event = 'InsertEnter'
}
