local input = require("src.engine.input")
local menu = require("src.visuals.ui.menu")
local session = require("src.app.session")
local settings = require("src.config.settings")

local menu_control = {}

local capturing = false

local repeat_delay = 0.2
local repeat_at = {}

local function repeated(action)
	if not input:is_down(action) then
		repeat_at[action] = nil
		return false
	end

	local now = love.timer.getTime()
	if repeat_at[action] and now < repeat_at[action] then
		return false
	end

	repeat_at[action] = now + repeat_delay
	return true
end

function menu_control.is_capturing()
	return capturing
end

function menu_control.reset()
	capturing = false
	repeat_at = {}
end

local function capture_key(name)
	local key = input.last_key
	if not key then
		return
	end
	capturing = false
	local option = menu:get_option(name)
	if key ~= "escape" and settings:rebind(option.id, menu:get_slot(name) or 1, key) then
		input:reload_keys()
	end
	menu:refresh(name)
end

local function run_command(flow, name, option)
	local command = option.label
	if command == "RESPAWN" then
		session.respawn()
		flow:set_state("normal")
	elseif command == "START" or command == "RESUME" then
		flow:set_state("normal")
	elseif command == "RESTART" then
		session.reset()
		session.load()
		flow:set_state("start")
	elseif command == "SETTINGS" then
		flow:set_state("settings")
	elseif command == "KEYBINDS" then
		flow:set_state("keybinds")
	elseif command == "QUIT" then
		love.event.quit()
	elseif command == "BACK" then
		flow:go_back()
	elseif command == "RESET" then
		if name == "keybinds" then
			settings:reset_keybinds()
			input:reload_keys()
		else
			settings:reset()
		end
		menu:refresh(name)
	end
end

function menu_control.update(flow, name)
	if capturing then
		capture_key(name)
		return
	end

	local option = menu:get_option(name)
	local kind = option.kind

	if kind == "action" and input:pressed("menu_interact") then
		run_command(flow, name, option)
	end

	if repeated("move_up") then
		menu:navigate(name, -1)
	end
	if repeated("move_down") then
		menu:navigate(name, 1)
	end

	if kind == "number" or kind == "enum" then
		local modified = false
		if repeated("move_left") then
			settings:adjust(option.label, -1)
			modified = true
		end
		if repeated("move_right") then
			settings:adjust(option.label, 1)
			modified = true
		end

		if modified then
			menu:refresh(name)
		end
	end

	if kind == "keybind" then
		local modified = false
		if input:pressed("menu_interact") then
			capturing = true
		end
		if repeated("move_left") then
			menu:navigate_slot("keybinds", -1)
			modified = true
		end
		if repeated("move_right") then
			menu:navigate_slot("keybinds", 1)
			modified = true
		end

		if modified then
			menu:refresh(name)
		end
	end
end

return menu_control
