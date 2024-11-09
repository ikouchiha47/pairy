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
local Crdt = require("crdt")

local M = {
	socket = nil,
	conn = nil,
	lconn = nil,
	thread = nil,
	crdt = nil,
	prevHash = "",
	prevRecvdHash = "",
	prevSentHash = "",

	syncing_paused = false,
	conflict_active = false,
	participant_is_user = true,
	typing_active = false,
	previousBuffer = nil,
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
	M.replicaID = md5.tohex(md5.sum(M.getMacAddress() .. tostring(os.time())))

	M.crdt = Crdt:new(M.replicaID)
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

	local success, err = M.lconn:connect(laddr, port)
	if not success then
		print("Local connection failed:", err)
		return
	end

	-- print("Connected to " .. laddr)
	print("Connected " .. address)

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
			-- local msg = M.currentBuffer()
			--
			-- if msg ~= "" then
			-- 	M.Send(msg)
			-- end
			M.sendBuffer()
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
	local currHash = md5.tohex(md5.sum(outgoingMsg))

	-- print("hashes", M.prevRecvdHash, currHash)
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
		-- print("Sent message")
	end
end

local prevMsg = ""

function M.sendBuffer()
	if not M.lconn then
		print("No active remote connection")
		return
	end

	local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local operations = M:generateSendOpts(buffer)

	for _, op in ipairs(operations) do
		local message = string.format("%s|{%d,%d,%s,%s}", op.replica_id, op.row, op.col, op.data or "", op.op_id)
		local outgoingMsg = message .. "\n"
		local currHash = md5.tohex(md5.sum(outgoingMsg))

		-- print("send hashes", prevMsg, M.prevRecvdHash, outgoingMsg, currHash)

		if M.prevSentHash == currHash then
			-- M.previousBuffer = buffer
			return
		end

		if op.op_id == "insert" then
			M.crdt:insert(op)
		elseif op.op_id == "remove" then
			M.crdt:delete(op)
		end

		local success, err = M.conn:send(outgoingMsg)
		if success then
			M.prevSentHash = currHash
			-- prevMsg = outgoingMsg
			-- print("Sent message:", outgoingMsg)
		else
			print("Failed to send message:", err)
		end
	end

	M.previousBuffer = buffer
end

function M:generateSendOpts(buffer)
	local operations = {}

	-- Track changes between the current and previous buffer states
	for row, line in ipairs(buffer) do
		local prevLine = M.previousBuffer and M.previousBuffer[row] or ""
		local maxLength = math.max(#line, #prevLine)

		for col = 1, maxLength do
			local currChar = line:sub(col, col)
			local prevChar = prevLine:sub(col, col)

			-- Fetch the current state from the CRDT's skiplist (row, col)
			local stateOp = M.crdt:stateAt(row, col)
			local stateData = stateOp and stateOp.data or nil
			local replicaID = stateOp and stateOp.replica_id or M.replicaID

			local newOp = nil

			if stateOp ~= nil and currChar ~= stateData then
				replicaID = M.replicaID
			elseif stateOp ~= nil then
				replicaID = stateOp.replica_id
			end
			-- print("hhhhhe", currChar, prevChar, dump(stateOp), "data", stateData, "replica", replicaID)

			-- Determine if a change is needed (insertion/deletion)
			if currChar ~= stateData then
				if currChar ~= "" then
					newOp = {
						replica_id = replicaID,
						row = row,
						col = col,
						data = currChar,
						op_id = "insert",
					}
				end

				if prevChar ~= "" then
					-- Create a remove operation
					newOp = {
						replica_id = replicaID,
						row = row,
						col = col,
						data = prevChar,
						op_id = "remove",
					}
				end
			end

			-- print(dump(newOp), dump(stateOp), replicaID, M.replicaID, "newOp")
			-- Add the operation to the list if it is valid
			if newOp ~= nil then
				table.insert(operations, newOp)
			end
		end
	end

	return operations
end

-- function dump(o)
-- 	if type(o) == "table" then
-- 		local s = "{ "
-- 		for k, v in pairs(o) do
-- 			if type(k) ~= "number" then
-- 				k = '"' .. k .. '"'
-- 			end
-- 			s = s .. "[" .. k .. "] = " .. dump(v) .. ","
-- 		end
-- 		return s .. "} "
-- 	else
-- 		return tostring(o)
-- 	end
-- end

function M.parse(data)
	local replica_id, operations = M:parseOps(data)
	local mode = "n"

	-- print("receiving", replica_id, M.replicaID)

	for _, op in ipairs(operations) do
		if replica_id == M.replicaID then
			-- print("replica id matches skipping")
			goto continue
		end

		op.replica_id = replica_id

		-- print("insert ", dump(op))
		if op.op_id == "insert" then
			M.crdt:insert(op)
			mode = "i"
		elseif op.op_id == "remove" then
			M.crdt:delete(op)
			mode = "i"
		end
		::continue::
	end

	if mode == "i" then
		M.crdt:merge()

		vim.schedule(function()
			local lines = vim.split(M.crdt.content, "\n")
			local buf = vim.api.nvim_get_current_buf()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		end)
	end
end

function M:parseOps(opString)
	local replica_id, ops = opString:match("^(.-)|(.+)$")
	local operations = {}

	for row, col, data, op_id in ops:gmatch("{(%d+),(%d+),([^,]+),([^}]+)}") do
		-- print("row", row, "col", col, "data", data, "op_id", op_id)
		table.insert(operations, {
			row = tonumber(row),
			col = tonumber(col),
			data = data,
			op_id = op_id,
			replica_id = replica_id,
		})
	end

	return replica_id, operations
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
	return opString .. "\n"
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
