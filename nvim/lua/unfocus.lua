M = {}

local function autocmd(events, ...)
	vim.api.nvim_create_autocmd(events, { callback = ... })
end

function M.setup()
	local initial_relativenumber, initial_cursorline, initial_signcol

	autocmd('VimEnter', function()
		initial_relativenumber = vim.o.relativenumber
		initial_cursorline = vim.o.cursorline
		initial_signcol = vim.o.signcolumn
	end)

	autocmd({ 'WinEnter', 'BufWinEnter' }, function()
		vim.opt.relativenumber = initial_relativenumber
		vim.opt.cursorline = initial_cursorline
		vim.opt.signcolumn = initial_signcol
	end)

	autocmd({ 'WinLeave' }, function()
		vim.opt.relativenumber = false
		vim.opt.cursorline = false
	end)
end

return M
