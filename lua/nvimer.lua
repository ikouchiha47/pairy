local function get_script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/pairy)")
end

local cwd = get_script_path()

local M = {
	socket = nil,
}

function M.setup(pwd)
	package.path = package.path .. ";" .. pwd .. "/lua/lua_modules/share/lua/5.1/?.lua"
	package.cpath = package.cpath .. ";" .. pwd .. "/lua/lua_modules/lib/lua/5.1/?.so"

	M.socket = require("socket")
end

function M.Connect(address)
	local conn = M.socket.tcp()
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
			print("Received " .. line)
			vim.api.nvim_command("execute 'normal! i' .. '" .. line .. "'")
		end
	end)
end

return M
