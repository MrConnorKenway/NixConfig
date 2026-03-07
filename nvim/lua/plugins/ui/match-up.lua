---@module 'match-up'
---@diagnostic disable: missing-fields

---@type LazyPluginSpec
return {
  'andymass/vim-matchup',
  ---@type matchup.Config
  opts = {
    matchparen = {
      offscreen = {
        scrolloff = 1, -- disable displaying on statusline
      },
      deferred = 1,
    },
    delim = {
      noskips = 2, -- skip pairs in strings and comments
    },
  },
}
