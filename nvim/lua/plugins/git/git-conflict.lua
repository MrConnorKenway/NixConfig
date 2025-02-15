vim.api.nvim_create_autocmd('User', {
  pattern = 'GitConflictDetected',
  callback = function(args)
    local bufnr = args.buf
    vim.keymap.set(
      'n',
      'co',
      '<Plug>(git-conflict-ours)',
      { silent = true, buffer = bufnr, desc = 'Git conflict choose ours' }
    )
    vim.keymap.set(
      'n',
      'ct',
      '<Plug>(git-conflict-theirs)',
      { silent = true, buffer = bufnr, desc = 'Git conflict choose theirs' }
    )
    vim.keymap.set(
      'n',
      'cb',
      '<Plug>(git-conflict-both)',
      { silent = true, buffer = bufnr, desc = 'Git conflict choose both' }
    )
    vim.keymap.set(
      'n',
      'cn',
      '<Plug>(git-conflict-none)',
      { silent = true, buffer = bufnr, desc = 'Git conflict choose none' }
    )
    vim.keymap.set(
      'n',
      '[x',
      '<Plug>(git-conflict-prev-conflict)',
      { silent = true, buffer = bufnr, desc = 'Git conflict previous conflict' }
    )
    vim.keymap.set(
      'n',
      ']x',
      '<Plug>(git-conflict-next-conflict)',
      { silent = true, buffer = bufnr, desc = 'Git conflict next conflict' }
    )
  end,
})

---@type LazyPluginSpec
return {
  'akinsho/git-conflict.nvim',
  opts = {
    default_mappings = false,
  },
}
