local M = {}

M.typing_active = false
M.debouncer = nil

function M.startTyping()
	M.typing_active = true

	if M.debouncer then
		M.debouncer:close()
	end

	M.debouncer = vim.defer_fn(function()
		M.typing_active = false
	end, 1000)
end

function M.stopTypingDelayed()
	vim.defer_fn(function()
		M.typing_active = false
	end, 1000)
end

function M.isTyping()
	return M.typing_active
end

function M.setupTypingDetection()
	local augroup = vim.api.nvim_create_augroup("TypingDetection", { clear = true })

	vim.api.nvim_create_autocmd("TextChangedI", {
		group = augroup,
		pattern = "*",
		callback = function()
			M.startTyping()
		end,
	})

	vim.api.nvim_create_autocmd("TextChanged", {
		group = augroup,
		pattern = "*",
		callback = function()
			M.stopTypingDelayed()
		end,
	})
end

return M
