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
local typer = require("track_typer")
local Crdt = require("crdtsimp")

local M = {
	socket = nil,
	conn = nil,
	lconn = nil,
	thread = nil,
	crdt = nil,
	prevHash = "",
	prevRecvdHash = "",

	syncing_paused = false,
	conflict_active = false,
	participant_is_user = true,
	typing_active = false,
}

local laddr = ""
local port = 0

-- Set up LuaSocket
-- TODO: capitalize exported methods
function M.setup(opts)
	local pwd = opts.pwd

	laddr = opts.laddr or "0.0.0.0"
	port = opts.port or 8080

	package.path = package.path .. ";" .. pwd .. "/lua/lua_modules/share/lua/5.1/?.lua"
	package.cpath = package.cpath .. ";" .. pwd .. "/lua/lua_modules/lib/lua/5.1/?.so"

	-- typer.setupTypingDetection()

	M.socket = require("socket")

	M.crdt = Crdt:new(md5.sum(M.getMacAddress()))
end

function M.getMacAddress()
	local handle = io.popen("ifconfig")
	if not handle then
		return ""
	end

	local result = handle:read("*a")
	handle:close()

	for line in result:gmatch("[^\r\n]+") do
		local mac = line:match("([%x]+:%x+:%x+:%x+:%x+:%x+)")
		if mac then
			return mac
		end
	end
	return "00:00:00:00:00:00"
end

function M.getReplicaID(user_id)
	local mac_address = M.getMacAddress()
	local timestamp = os.time() -- or os.clock() for higher precision
	local unique_id = string.format("%s-%s-%d", mac_address, user_id, timestamp)

	return unique_id
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

			if not line and err ~= "timeout" then
				print("Receive error:", err)
				return
			elseif line then
				vim.schedule(function()
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

	print("sending", outgoingMsg)

	local success, err = M.conn:send(outgoingMsg)
	if not success then
		print("Failed to send message:", err)
	else
		M.prevRecvdHash = currHash
		print("Sent message")
	end
end

function M.parse(data)
	local currHash = md5.sum(data)
	if M.prevHash == currHash then
		return
	end

	M.prevHash = currHash
	local mode, line = self:parseOps(data)

	line = line:gsub("\\xn", "\n")

	if mode == "i" then
		vim.schedule(function()
			print("Received text to insert: " .. line)

			local lines = vim.split(line, "\n", { trimempty = true })
			local buf = vim.api.nvim_get_current_buf()

			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
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

function M:parseOps(opString)
	local mode, ops = opString:match("^(%a)|(.+)$")
	local operations = {}

	for row, col, data, op_id in ops:gmatch("{(%d+),(%d+),(%a),(%a+)}") do
		table.insert(operations, {
			row = tonumber(row),
			col = tonumber(col),
			data = data,
			op_id = op_id,
		})
	end

	return mode, operations
end

function M.currentBuffer()
	local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local operations = {}
	local mode = "i" -- Specify the mode, assuming insert mode as example

	for row, line in ipairs(buffer) do
		for col = 1, #line do
			local char = line:sub(col, col)
			table.insert(operations, {
				row = row,
				col = col,
				data = char,
				op_id = "insert",
			})
		end
	end

	local opString = mode .. "|"
	for _, op in ipairs(operations) do
		opString = opString .. string.format("{%d,%d,%s,%s}", op.row, op.col, op.data, op.op_id)
	end

	print(opString)
	return opString
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
