return {
  'rmagatti/goto-preview',
  keys = {
    {
      'gp',
      function() require('goto-preview').goto_preview_definition {} end,
      desc = 'Preview LSP definition in popup'
    },
    {
      'gr',
      function() require('goto-preview').goto_preview_references {} end,
      desc = 'Preview LSP references in popup'
    },
  },
  opts = {
    border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' }
  }
}
