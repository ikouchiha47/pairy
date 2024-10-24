local function get_script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/pairy)")
end

local cwd = get_script_path()

local M = {}

function M.setup(pwd)
	package.path = package.path .. ";" .. pwd .. "/lua/lua_modules/share/lua/5.1/?.lua"
	package.cpath = package.cpath .. ";" .. pwd .. "/lua/lua_modules/lib/lua/5.1/?.so"

	-- M.socket = require("socket")
end

function M.Connect(address)
	-- M.conn = M.socket.tcp()
	-- M.conn:settimeout(5)
	--
	-- local success, err = M.conn:connect(address, 8080)
	--
	-- if not success then
	-- 	print("Connection failed:", err)
	-- 	return
	-- end

	local function receive_loop(address, path, cpath)
		package.path = path
		package.cpath = cpath

		local socket = require("socket")
		local conn = socket.tcp()

		conn:settimeout(5)

		local success, err = conn:connect(address, 8080)

		if not success then
			print("Connection failed:", err)
			return
		end

		print("Connected to " .. address)
		while true do
			local line, err = conn:receive("*l")
			if err then
				-- print("Receive error:", err)
				if err == "timeout" then
					goto continue
				end

				print("exiting for", err)
				break
			end

			-- Process received command
			print("Received " .. line)
			vim.schedule(function()
				vim.api.nvim_command("execute 'normal! i' .. '" .. line .. "'")
			end)
			::continue::
		end
	end

	-- Start the thread with the connection explicitly passed
	vim.uv.new_thread(receive_loop, address, package.path, package.cpath)
end

-- function M.Disconnect()
-- 	if M.conn then
-- 		M.conn:close()
-- 		M.conn = nil
-- 		print("Connection closed.")
-- 	end
-- end

return M
