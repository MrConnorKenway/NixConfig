---@type LazyPluginSpec
return {
  'rmagatti/goto-preview',
  keys = {
    {
      'gp',
      function()
        require('goto-preview').goto_preview_definition {}
      end,
      desc = 'Preview LSP definition in popup',
    },
    {
      'gr',
      function()
        local ok, snacks = pcall(require, 'snacks')
        if not ok then
          return
        end

        snacks.picker {
          finder = 'lsp_references',
          confirm = function(picker)
            local selection = picker:current()
            picker:close()

            if selection ~= nil then
              require('goto-preview.lib').open_floating_win(
                vim.uri_from_fname(selection.file),
                selection.pos
              )
            end
          end,
        }
      end,
      desc = 'Preview LSP references in popup',
    },
  },
  opts = {
    border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
  },
}
