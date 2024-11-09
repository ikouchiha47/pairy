local Pairy = require("nvimer")

-- Start the server
vim.api.nvim_create_user_command("PairyServe", Pairy.LocalConnect, {})

-- Command to connect
vim.api.nvim_create_user_command("PairyPair", function(opts)
	Pairy.Connect(opts.args)
end, { nargs = 1 })

-- vim.api.nvim_create_user_command("Send", function(opts)
-- 	Pairy.Send(opts.args)
-- end, { nargs = 1 })

vim.api.nvim_create_user_command("PairyUnPair", Pairy.UnPair, {})

vim.api.nvim_create_user_command("PairyKill", Pairy.Kill, {})

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		Pairy.Kill()
	end,
})
