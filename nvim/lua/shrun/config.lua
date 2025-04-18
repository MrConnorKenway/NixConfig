local M = {}

M.sidebar_width = 48
M.sidebar_height = 16

M.shell_width = 80
M.shell_height = 20
M.shell_fzf_default_opts = '--layout=reverse --height=100%'
M.shell_integration_path = '%s/.config/nvim/shell_integration'

M.separator_stem = '─'

-- Display elapsed time of task if its running time is longer than this threshold
M.long_time_threshold = 3000
M.timer_repeat_interval = 1000

M.default_highlights = {
  ShrunHighlightTaskIDLE = 'Normal',
  ShrunHighlightTaskRUNNING = 'Constant',
  ShrunHighlightTaskSUCCESS = 'DiagnosticOk',
  ShrunHighlightTaskFAILED = 'DiagnosticError',
  ShrunHighlightTaskFocus = 'CursorLine',
  ShrunHighlightTaskName = 'Title',
  ShrunHighlightTaskOutPrefix = 'Comment',
}

return M
