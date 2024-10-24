package.path = package.path .. ";/home/darksied/dev/pairy/lua/lua_modules/share/lua/5.1/?.lua"
package.cpath = package.cpath .. ";/home/darksied/dev/pairy/lua/lua_modules/lib/lua/5.1/?.so"

local socket = require("socket")
local conn

local M = {}

function M.Connect(address)
	conn = socket.tcp()
	conn:settimeout(5) -- Set timeout for connection
	local success, err = conn:connect(address, 8080)

	if not success then
		print("Connection failed:", err)
		return
	end

	print("Connected to " .. address)

	vim.loop.new_thread(function()
		while true do
			local line, err = conn:receive("*l")
			if err then
				break
			end

			-- Process received command
			vim.api.nvim_command("execute 'normal! i' .. '" .. line .. "'")
		end
	end)
end

return M
