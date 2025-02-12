---@type vim.lsp.Config
return {
  cmd = { 'lua-language-server' },
  root_markers = {
    '.luarc.json',
    '.luarc.jsonc',
    '.luacheckrc',
    '.stylua.toml',
    'stylua.toml',
    'selene.toml',
    'selene.yml',
    '.git',
  },
  filetypes = { 'lua' },
  single_file_support = true,
  log_level = vim.lsp.protocol.MessageType.Warning,
  on_init = function(client)
    for _, workspace in ipairs(client.workspace_folders) do
      if workspace.name:match('[Nn]ix[Cc]onfig') then
        client.settings = vim.tbl_deep_extend('force', client.settings, {
          Lua = {
            runtime = {
              version = 'LuaJIT',
            },
            workspace = {
              checkThirdParty = false,
              library = {
                vim.env.VIMRUNTIME,
                vim.fn.stdpath('data') .. '/lazy/lazy.nvim/lua',
              },
            },
          },
        })
        return
      end
    end
  end,
}
