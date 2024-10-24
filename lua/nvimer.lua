-- [[
-- This is how it goes.
-- As a Sender, neovim is responsibile for
-- sending the data to the remote address.
--
-- This data, is received by the golang server
-- on the other end.
--
-- As a receiver, lua connects to the localhost golang
-- server, and receives the data.
-- For the final product, the data has to be split into
-- {vim_mode, line}
--
-- ]]

local M = {
	socket = nil,
	conn = nil,
	lconn = nil,
	thread = nil,
}

local laddr = "0.0.0.0"
local port = 8080

-- Set up LuaSocket
function M.setup(pwd)
	package.path = package.path .. ";" .. pwd .. "/lua/lua_modules/share/lua/5.1/?.lua"
	package.cpath = package.cpath .. ";" .. pwd .. "/lua/lua_modules/lib/lua/5.1/?.so"

	M.socket = require("socket")
end

-- Connect to the TCP server
function M.Connect(address)
	if not M.socket then
		print("Failed to connect to socket")
		return
	end

	M.lconn = M.socket.tcp()
	M.conn = M.socket.tcp()

	local success, err = M.conn:connect(address, port)
	if not success then
		print("Remote Connection failed:", err)
		return
	end

	print("Connected to " .. address)

	local success, err = M.lconn:connect(laddr, port)
	if not success then
		print("Local connection failed:", err)
		return
	end

	print("Connected to " .. laddr)

	-- Start a coroutine to handle receiving messages
	M.thread = vim.schedule_wrap(function()
		while true do
			local line, err = M.conn:receive("*l")
			if err then
				print("Receive error:", err)
				break
			end

			vim.schedule(function()
				print("Received from server: " .. line)
				vim.api.nvim_command("execute 'normal! i" .. line .. "'")
			end)
		end
	end)

	-- Run the coroutine for receiving messages
	M.thread()
end

-- Send a message to the Go server
function M.Send(message)
	if not M.lconn then
		print("No active connection. Please connect first.")
		return
	end

	-- Send message followed by a newline
	local success, err = M.lconn:send(message .. "\n")
	if not success then
		print("Failed to send message:", err)
	else
		print("Sent message: " .. message)
	end
end

-- Close the connection
function M.UnPair()
	if M.conn then
		M.conn:close()
		M.conn = nil

		M.lconn:close()
		M.lconn = nil

		print("Connections closed.")
	end
end

return M
