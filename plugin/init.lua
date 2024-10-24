local Pairy = require("nvimer")

-- Command to connect
vim.api.nvim_create_user_command("Pair", function(opts)
	Pairy.Connect(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("Send", function(opts)
	Pairy.Send(opts.args)
end, {})

vim.api.nvim_create_user_command("UnPair", Pairy.UnPair, {})
