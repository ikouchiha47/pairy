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

local md5 = require("md5")

local M = {
	socket = nil,
	conn = nil,
	lconn = nil,
	thread = nil,
	prevHash = "",
	prevRecvdHash = "",
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

	M.conn:settimeout(0)
	M.lconn:settimeout(0)

	M.serverD()
	M.receiverD()
end

function M.serverD()
	vim.loop.new_timer():start(
		0,
		500,
		vim.schedule_wrap(function()
			local msg = M.currentBuffer()
			if msg ~= "" then
				print(msg)
				M.Send(msg)
			end
		end)
	)
end

function M.receiverD()
	if not M.conn then
		print("No active remote connection.")
		return
	end

	vim.loop.new_timer():start(
		0,
		100,
		vim.schedule_wrap(function()
			local line, err = M.lconn:receive("*l")

			-- Handle only if there's no error (no message or timeout will not block)
			if not line and err ~= "timeout" then
				print("Receive error:", err)
				return
			elseif line then
				-- Received message successfully
				vim.schedule(function()
					-- vim.api.nvim_command("execute 'normal! i" .. line .. "'")
					M.parse(line)
				end)
			end
		end)
	)
end

-- Send a message to the Go server
function M.Send(message)
	if not M.lconn then
		print("No active remote connection")
		return
	end

	local outgoingMsg = message .. "\n"
	local currHash = md5.sum(outgoingMsg)

	-- Send message followed by a newline
	if M.prevRecvdHash == currHash then
		return
	end

	local success, err = M.conn:send(outgoingMsg)
	if not success then
		print("Failed to send message:", err)
	else
		M.prevRecvdHash = currHash
		print("Sent message: " .. message)
	end
end

function M.parse(data)
	local currHash = md5.sum(data)
	if M.prevHash == currHash then
		return
	end

	M.prevHash = currHash
	local mode, line = data:match("^(%a)|(.+)$")

	if mode == "i" then
		vim.schedule(function()
			print("Received text to insert: " .. line)
			-- vim.api.nvim_put({ line }, "l", true, true)
			local buf = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
		end)
	elseif mode == "v" then
		vim.schedule(function()
			print("Executing Vim command: " .. line)
			vim.api.nvim_command(line)
		end)
	else
		print("Unsupported mode received:", mode)
	end
end

function M.currentBuffer()
	local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local buffer_string = table.concat(buffer)

	if buffer_string == "" then
		return ""
	end

	return "i|" .. buffer_string
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
