local Pairy = require("nvimer")

-- Command to connect
vim.api.nvim_create_user_command("Pair", function(opts)
	Pairy.Connect(opts.args)
end, { nargs = 1 })
