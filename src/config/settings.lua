local render_cfg = require("src.config.render_config")
local bindings = require("src.config.bindings")
local game_cfg = require("src.config.game_config")
local debug_state = require("src.debug.debug_state")
local utils = require("src.utils")
local settings = {}

local function apply_fonts()
	local runtime = require("src.config.runtime")
	local scene = require("src.visuals.render.scene")
	runtime:load()
	scene:reload_fonts()
end

local function apply_window()
	require("src.config.runtime"):setup_window()
end

local APPLY = {
	fonts = apply_fonts,
	window = apply_window,
}

local descriptors = {
	{
		id = "GAMMA",
		kind = "number",
		path = { render_cfg, "lighting", "brightness" },
		min = -0.5,
		max = 0.5,
		step = 0.05,
	},
	{
		id = "FULLSCREEN",
		kind = "enum",
		path = { game_cfg, "window", "fullscreen" },
		values = { false, true },
		labels = { "OFF", "ON" },
		apply = "window",
	},
	{
		id = "FONT",
		kind = "enum",
		path = { render_cfg, "font", "use_pixel" },
		values = { true, false },
		labels = { "PIXEL", "SMOOTH" },
		apply = "fonts",
	},
	{
		id = "COLOR",
		kind = "enum",
		path = { debug_state, "bw_mode" },
		values = { 0, 1, 2 },
		labels = { "FULL", "BW TILES", "BW ALL" },
	},
	{
		id = "SCALE",
		kind = "number",
		path = { render_cfg, "font", "scale" },
		min = 1,
		max = 6,
		step = 0.2,
		apply = "fonts",
	},
}

local by_id = {}
for _, descriptor in ipairs(descriptors) do
	by_id[descriptor.id] = descriptor
end

local function read(descriptor)
	local path = descriptor.path
	local node = path[1]
	for i = 2, #path - 1 do
		node = node[path[i]]
	end
	return node[path[#path]]
end

local function write(descriptor, value)
	local path = descriptor.path
	local node = path[1]
	for i = 2, #path - 1 do
		node = node[path[i]]
	end
	node[path[#path]] = value
end
local default_values = {}
for _, descriptor in ipairs(descriptors) do
	default_values[descriptor.id] = read(descriptor)
end

local function index_of(descriptor, value)
	for i, candidate in ipairs(descriptor.values) do
		if candidate == value then
			return i
		end
	end
	return 1
end

local EMPTY = ""

local default_keys = {}
for _, binding in ipairs(bindings) do
	local keys = {}
	for i = 2, #binding do
		keys[i - 1] = binding[i]
	end
	default_keys[binding[1]] = keys
end

local MAX_SLOTS = 2

local function set_keys(binding, keys)
	for i = #binding, 2, -1 do
		binding[i] = nil
	end
	for i = 1, math.min(#keys, MAX_SLOTS) do
		binding[i + 1] = keys[i]
	end
end

local function is_rebindable(binding)
	return binding.category ~= "debug" and binding[1] ~= "select_slot"
end

local function binding_of(action)
	for _, binding in ipairs(bindings) do
		if is_rebindable(binding) and binding[1] == action then
			return binding
		end
	end
	return nil
end

function settings:get_keybinds()
	local ret = {}
	for _, binding in ipairs(bindings) do
		if is_rebindable(binding) then
			table.insert(ret, binding)
		end
	end
	return ret
end

function settings:binding_texts(action)
	local binding = binding_of(action)
	if not binding then
		return nil
	end
	local ret = {}
	for i = 2, #binding do
		table.insert(ret, binding[i])
	end
	if #ret < 2 then
		table.insert(ret, EMPTY)
	end
	return ret
end

local reserved = { "escape", "return", "kpenter" }
function settings:rebind(action, slot, key)
	if utils.contains(reserved, key) then
		return false
	end
	local target = binding_of(action)
	if not target then
		return false
	end

	for _, binding in ipairs(bindings) do
		if is_rebindable(binding) then
			for i = 2, #binding do
				if binding[i] == key and not (binding == target and i == slot + 1) then
					binding[i] = EMPTY
				end
			end
		end
	end

	target[slot + 1] = key
	return true
end

function settings:reset_keybinds()
	for _, binding in ipairs(bindings) do
		set_keys(binding, default_keys[binding[1]])
	end
end

function settings:get(id)
	return read(by_id[id])
end

function settings:set(id, value)
	local descriptor = by_id[id]
	if value == read(descriptor) then
		return
	end
	write(descriptor, value)
	local apply = descriptor.apply and APPLY[descriptor.apply]
	if apply then
		apply()
	end
end

function settings:adjust(id, dir)
	local descriptor = by_id[id]
	if descriptor.kind == "number" then
		local steps = math.floor(read(descriptor) / descriptor.step + 0.5) + dir
		local value = math.max(descriptor.min, math.min(descriptor.max, steps * descriptor.step))
		self:set(id, value)
	else
		local index = ((index_of(descriptor, read(descriptor)) - 1 + dir) % #descriptor.values) + 1
		self:set(id, descriptor.values[index])
	end
end

function settings:value_text(id)
	local descriptor = by_id[id]
	if descriptor.kind == "number" then
		return string.format("%.2f", read(descriptor))
	end
	return descriptor.labels[index_of(descriptor, read(descriptor))]
end

function settings:reset()
	for _, descriptor in ipairs(descriptors) do
		self:set(descriptor.id, default_values[descriptor.id])
	end
end

function settings:each()
	return ipairs(descriptors)
end

local SETTINGS_SAVE_FILE = "settings.cfg"

function settings:save()
	local lines = {}
	for _, d in settings:each() do
		table.insert(lines, d.id .. "=" .. tostring(settings:get(d.id)))
	end
	love.filesystem.write(SETTINGS_SAVE_FILE, table.concat(lines, "\n"))
end

local KEYBINDS_SAVE_FILE = "keybinds.cfg"

local function split_keys(raw)
	local keys = {}
	for field in (raw .. ","):gmatch("([^,]*),") do
		table.insert(keys, field)
	end
	return keys
end

function settings:save_keybinds()
	local lines = {}
	for _, binding in ipairs(self:get_keybinds()) do
		local keys = {}
		for i = 2, #binding do
			table.insert(keys, binding[i])
		end
		table.insert(lines, binding[1] .. "=" .. table.concat(keys, ","))
	end
	love.filesystem.write(KEYBINDS_SAVE_FILE, table.concat(lines, "\n"))
end

function settings:load_keybinds()
	if not love.filesystem.getInfo(KEYBINDS_SAVE_FILE) then
		return
	end
	local contents = love.filesystem.read(KEYBINDS_SAVE_FILE)
	if not contents then
		return
	end
	for line in contents:gmatch("[^\n]+") do
		local action, raw = line:match("^(.-)=(.*)$")
		local binding = action and binding_of(action)
		if binding then
			set_keys(binding, split_keys(raw))
		end
	end
end

local function parse_value(descriptor, raw)
	if descriptor.kind == "number" then
		local n = tonumber(raw)
		if not n then
			return nil
		end
		return math.max(descriptor.min, math.min(descriptor.max, n))
	end
	for _, candidate in ipairs(descriptor.values) do
		if tostring(candidate) == raw then
			return candidate
		end
	end
	return nil
end

function settings:load()
	if not love.filesystem.getInfo(SETTINGS_SAVE_FILE) then
		return
	end
	local contents = love.filesystem.read(SETTINGS_SAVE_FILE)
	if not contents then
		return
	end
	for line in contents:gmatch("[^\n]+") do
		local id, raw = line:match("^(.-)=(.*)$")
		local descriptor = id and by_id[id]
		if descriptor then
			local value = parse_value(descriptor, raw)
			if value ~= nil then
				write(descriptor, value)
			end
		end
	end
end

return settings
