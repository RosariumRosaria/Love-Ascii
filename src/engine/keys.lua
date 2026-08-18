local bindings = require("src.config.bindings")

local keys = {
	down_keys = {},
	pressed_keys = {},
	released_keys = {},
	move_recency = {},
	buffered_keys = {},
	last_key = nil,
}

local keys_of = {}

local move_axis_of_key
local function get_move_of_key(key)
	if not move_axis_of_key then
		move_axis_of_key = {}
		for _, k in ipairs(keys_of.move_left or {}) do
			move_axis_of_key[k] = { axis = "x", dir = -1 }
		end
		for _, k in ipairs(keys_of.move_right or {}) do
			move_axis_of_key[k] = { axis = "x", dir = 1 }
		end
		for _, k in ipairs(keys_of.move_up or {}) do
			move_axis_of_key[k] = { axis = "y", dir = -1 }
		end
		for _, k in ipairs(keys_of.move_down or {}) do
			move_axis_of_key[k] = { axis = "y", dir = 1 }
		end
	end
	return move_axis_of_key[key]
end

local function remove_from_recency(list, key)
	for i, k in ipairs(list) do
		if k == key then
			table.remove(list, i)
			return
		end
	end
end

function keys:reload()
	for _, binding in ipairs(bindings) do
		local list = {}
		for i = 2, #binding do
			list[i - 1] = binding[i]
		end
		for _, key in ipairs(binding.fixed or {}) do
			table.insert(list, key)
		end
		keys_of[binding[1]] = list
	end

	move_axis_of_key = nil
end

function keys:reset()
	self.down_keys = {}
	self.pressed_keys = {}
	self.released_keys = {}
	self.move_recency = {}
	self.buffered_keys = {}
	self.last_key = nil
	self.buffer_reading = false
	self.buffer_set = nil
	self:reload()
end

function keys:end_frame()
	self.pressed_keys = {}
	self.released_keys = {}
	self.last_key = nil
end

function love.keypressed(key)
	keys.down_keys[key] = true
	keys.pressed_keys[key] = true
	keys.last_key = key
	if get_move_of_key(key) then
		remove_from_recency(keys.move_recency, key)
		table.insert(keys.move_recency, key)
	end
end

function love.keyreleased(key)
	keys.down_keys[key] = nil
	keys.released_keys[key] = true
	if get_move_of_key(key) then
		remove_from_recency(keys.move_recency, key)
	end
end

local function mouse_to_key(button)
	return "mouse" .. button
end

function love.mousepressed(_, _, button)
	local key = mouse_to_key(button)
	keys.down_keys[key] = true
	keys.pressed_keys[key] = true
end

function love.mousereleased(_, _, button)
	local key = mouse_to_key(button)
	keys.down_keys[key] = nil
	keys.released_keys[key] = true
end

local function has(action, state_table)
	local list = keys_of[action]
	if not list then
		return false
	end

	for _, key in ipairs(list) do
		if state_table[key] then
			return true
		end
	end
	return false
end

function keys:get_keys(action)
	return keys_of[action]
end

function keys:get_last_key()
	return self.last_key
end

function keys:is_down(action)
	local source = self.buffer_reading and self.buffer_set or self.down_keys
	return has(action, source)
end

function keys:pressed(action)
	return has(action, self.pressed_keys)
end

function keys:released(action)
	return has(action, self.released_keys)
end

function keys:pressed_slot()
	for index, key in ipairs(keys_of.select_slot or {}) do
		if self.pressed_keys[key] then
			return index
		end
	end
	return nil
end
function keys:get_direction(cardinal_only)
	local x, y = 0, 0

	local recency = self.buffer_reading and self.buffered_keys or self.move_recency
	for i = #recency, 1, -1 do
		local binding = get_move_of_key(recency[i])
		if binding then
			if binding.axis == "y" and y == 0 then
				y = binding.dir
			elseif binding.axis == "x" and x == 0 then
				x = binding.dir
			end
			if cardinal_only then
				break
			end
		end
	end

	return { x = x, y = y }
end

function keys:is_moving_live()
	return #self.move_recency > 0
end

function keys:buffer_pressed()
	for key in pairs(self.pressed_keys) do
		remove_from_recency(self.buffered_keys, key)
		table.insert(self.buffered_keys, key)
	end
end

function keys:has_buffer()
	return #self.buffered_keys > 0
end

function keys:clear_buffer()
	self.buffered_keys = {}
end

function keys:read_buffered(fn)
	local set = {}
	for _, key in ipairs(self.buffered_keys) do
		set[key] = true
	end
	self.buffer_set = set
	self.buffer_reading = true
	local ok, result = pcall(fn)
	self.buffer_reading = false
	self.buffer_set = nil
	if not ok then
		error(result, 0)
	end
	return result
end

return keys
