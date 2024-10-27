local Node = {}
Node.__index = Node

function Node.new(key, op, level)
	local self = setmetatable({}, Node)
	self.key = key
	self.data = op.data
	self.timestamp = op.timestamp -- timestamp or version
	self.replica_id = op.replica_id -- participant replica ID
	self.op_id = op.op_id -- Unique operation ID
	self.row = op.row
	self.col = op.col
	self.forward = {} -- Forward references for each level
	self.deleted = false -- Tombstone for logical delete
	for i = 1, level do
		self.forward[i] = nil
	end
	return self
end

-- Define the CRDT-enabled Skip List
local SkipList = {}
SkipList.__index = SkipList

local MAX_LEVEL = 16
local P = 0.5

-- Create a new CRDT-enabled skip list
function SkipList.new()
	local self = setmetatable({}, SkipList)
	local op = { data = nil, timestamp = nil, replica_id = nil, op_id = nil }

	self.level = 1
	self.header = Node.new(nil, op, MAX_LEVEL)
	return self
end

function SkipList:random_level()
	local level = 1
	while math.random() < P and level < MAX_LEVEL do
		level = level + 1
	end
	return level
end

-- CRDT Insert: Adds or updates a key based on timestamp, replica_id, and op_id
function SkipList:put(key, op)
	local update = {}
	local current = self.header

	-- Find positions to update at each level
	for i = self.level, 1, -1 do
		while current.forward[i] and current.forward[i].key < key do
			current = current.forward[i]
		end
		update[i] = current
	end

	-- Check if key already exists
	current = current.forward[1]
	if current and current.key == key then
		if
			(op.timestamp > current.timestamp)
			or (op.timestamp == current.timestamp and op.replica_id > current.replica_id)
		then
			current.data = op.data
			current.timestamp = op.timestamp
			current.replica_id = op.replica_id
			current.op_id = op.op_id
			current.row = op.row
			current.col = op.col
			current.deleted = false
		end
	else
		local new_level = self:random_level()
		if new_level > self.level then
			for i = self.level + 1, new_level do
				update[i] = self.header
			end
			self.level = new_level
		end

		local new_node = Node.new(key, op, new_level)
		for i = 1, new_level do
			new_node.forward[i] = update[i].forward[i]
			update[i].forward[i] = new_node
		end
	end
end

-- CRDT Delete: Marks a key as deleted with a tombstone if conditions met
function SkipList:delete(key, op)
	local current = self.header

	for i = self.level, 1, -1 do
		while current.forward[i] and current.forward[i].key < key do
			current = current.forward[i]
		end
	end

	current = current.forward[1]
	if current and current.key == key then
		if
			(op.timestamp > current.timestamp)
			or (op.timestamp == current.timestamp and op.replica_id > current.replica_id)
		then
			current.deleted = true
			current.timestamp = op.timestamp
			current.replica_id = op.replica_id
			current.op_id = op.op_id
			current.row = op.row
			current.col = op.col
		end
	end
end

-- Retrieve a value, checking for tombstones
function SkipList:get(key)
	local current = self.header

	for i = self.level, 1, -1 do
		while current.forward[i] and current.forward[i].key < key do
			current = current.forward[i]
		end
	end

	current = current.forward[1]
	if current and current.key == key and not current.deleted then
		return current.data
	else
		return nil -- Return nil if deleted or not found
	end
end

function SkipList:to_list()
	local content = {}
	local current = self.header.forward[1]

	while current do
		if not current.deleted then
			table.insert(content, current) -- needs a to op function
		end

		current = current.forward[1]
	end

	table.sort(content, function(a, b)
		if a.row < b.row then
			if a.col < b.col then
				if a.timestamp < b.timestamp then
					return true
				end
				return true
			end

			return true
		end
		return false
	end)

	-- -- Combine text parts to form the full content string
	-- local full_text = ""
	-- for _, entry in ipairs(content) do
	-- 	full_text = full_text .. entry.text -- Concatenate each piece of text
	-- end
	--

	return content
end

return SkipList
