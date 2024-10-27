-- local pwd = os.getenv("PWD")
-- package.path = package.path .. ";" .. pwd .. "/lua/?.lua;" .. pwd .. "/lua/lua_modules/share/lua/5.1/?.lua"
-- package.cpath = package.cpath .. ";" .. pwd .. "/lua/?.lua;" .. pwd .. "/lua/lua_modules/lib/lua/5.1/?.so"

local Skiplist = require("skiplist")

local CRDT = {}

function CRDT:new(replica_id)
	self.versions = {}
	self.content_rows = {} -- 2d array, stores array of columns
	self.replica_id = replica_id
	self.skiplist = Skiplist.new()

	return self
end

function CRDT:getContent()
	return self.content
end

function CRDT:gen_next_version(user)
	local currVersion = self.versions[user] or 0
	local nextVersion = currVersion + 0.1

	self.versions[user] = nextVersion
	return nextVersion
end

--[[
-- op = { row, col, data, op_id }
--]]

function CRDT:insert(op)
	local key = op.row .. ":" .. op.col

	op.timestamp = self:gen_next_version(op.replica_id)
	self.skiplist:put(key, op)
end

function CRDT:delete(op)
	local key = op.row .. ":" .. op.col

	op.timestamp = self:gen_next_version(op.replica_id)
	self.skiplist:delete(key, op)
end

function CRDT:merge()
	local ops = self.skiplist:to_list()

	for _, op in ipairs(ops) do
		if not self.content_rows[op.row] then
			self.content_rows[op.row] = {}
		end

		if op.op_id == "insert" then
			self.content_rows[op.row][op.col] = op.data
		elseif op.op_id == "remove" then
			self.content_rows[op.row][op.col] = nil
		end
	end

	local content = ""

	for _, row in pairs(self.content_rows) do
		local row_content = {}

		for _, colVal in pairs(row) do
			if colVal ~= nil then
				table.insert(row_content, colVal)
			end
		end

		content = content .. table.concat(row_content, "") .. "\n"
	end

	self.content = content:sub(1, -2)
	return self
end

function CRDT:insert_text(original, pos, data)
	return original:sub(1, pos) .. data .. original:sub(pos + 1)
end

function CRDT:delete_text(original, pos, n_data)
	return original:sub(1, pos) .. original:sub(pos + n_data + 1)
end

-- zig like in file tests
--

function testCRDTHappyFlow()
	local crdt = CRDT:new()

	crdt:insert({ replica_id = 1, row = 1, col = 1, data = "Hello ", op_id = "insert" })
	crdt:insert({ replica_id = 2, row = 1, col = 7, data = "World ", op_id = "insert" })

	crdt:merge()

	assert(crdt:getContent() == "Hello World ")

	crdt:insert({ replica_id = 1, row = 1, col = 13, data = "Lore ", op_id = "insert" })
	crdt:delete({ replica_id = 2, row = 1, col = 7, op_id = "remove" })
	crdt:insert({ replica_id = 2, row = 1, col = 7, data = "Letty ", op_id = "insert" })

	crdt:merge()

	assert(crdt:getContent() == "Hello Letty Lore ")
end

function testCRDTLWW() end

testCRDTHappyFlow()

return CRDT
