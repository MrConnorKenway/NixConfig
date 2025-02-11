---@type LazyPluginSpec
return {
  'lewis6991/gitsigns.nvim',
  config = function()
    local gitsigns = require('gitsigns')
    gitsigns.setup {
      signs = {
        changedelete = { text = '┃' }
      },
      signs_staged = {
        changedelete = { text = '┃' }
      },
      sign_priority = 100,
      preview_config = {
        border = 'rounded'
      }
    }
    vim.keymap.set('n', ']c', function()
      if vim.api.nvim_buf_get_name(0):match('fugitive://') then
        vim.cmd('normal! ]c | zz')
      else
        gitsigns.nav_hunk('next', { target = 'all' })
      end
    end, { desc = 'Go to next git change' })
    vim.keymap.set('n', '[c', function()
      if vim.api.nvim_buf_get_name(0):match('fugitive://') then
        vim.cmd('normal! [c | zz')
      else
        gitsigns.nav_hunk('prev', { target = 'all' })
      end
    end, { desc = 'Go to previous git change' })
    vim.keymap.set('n', '<leader>u', gitsigns.reset_hunk, { desc = 'Git reset hunk' })
    vim.keymap.set('v', '<leader>u', ":'<,'>Gitsigns reset_hunk<cr>",
      { desc = 'Git reset hunk of visual selected range', silent = true })
    vim.keymap.set('n', '<leader>b', gitsigns.blame_line, { desc = 'Git blame inline' })
    vim.keymap.set('n', 'ga', gitsigns.stage_hunk, { desc = 'Git stage hunk' })
    vim.keymap.set('v', 'ga', ":'<,'>Gitsigns stage_hunk<cr>",
      { desc = 'Git stage hunk of visual selected range', silent = true })
    vim.keymap.set('n', 'gi', gitsigns.preview_hunk_inline, { desc = 'Git preview hunk inline' })
  end
}
