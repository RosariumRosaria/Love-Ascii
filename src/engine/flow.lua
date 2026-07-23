local input = require("src.engine.input")
local state = require("src.engine.state")
local menu = require("src.visuals.ui.menu")
local session = require("src.engine.session")
local settings = require("src.config.settings")
local entities = require("src.sim.entities")
local hud = require("src.visuals.ui.hud")
local flow = {}

local menu_for_state = { paused = "pause", start = "start", dead = "dead", settings = "settings" }
local back = nil

local function go_back()
	local previous = back
	back = nil
	flow:set_state(previous)
	settings:save()
end

function flow:set_state(new_state)
	local previous = state:get()

	if not state:set(new_state) then
		return false
	end
	local current = state:get()

	local leaving = previous ~= current and menu_for_state[previous]
	if leaving then
		back = previous
		menu:set_visible(leaving, false)
	end

	local entering = menu_for_state[current]
	if entering then
		if current == "dead" then
			menu:set_death_reason("Killed by a " .. (entities.player.death_source or "Unknown"))
		end
		menu:set_visible(entering, true)
	end

	hud:set_visible(current == "normal")
	return true
end

local function handle_menu(self, name)
	local option = menu:get_option(name)
	local kind = option.kind
	if input:pressed("menu_interact") then
		if kind == "action" then
			local command = option.label
			if command == "RESPAWN" then
				session.respawn()
				self:set_state("normal")
			elseif command == "START" or command == "RESUME" then
				self:set_state("normal")
			elseif command == "RESTART" then
				session.reset()
				session.load()
				self:set_state("start")
			elseif command == "SETTINGS" then
				self:set_state("settings")
			elseif command == "QUIT" then
				love.event.quit()
			elseif command == "BACK" then
				go_back()
			end
		end
	end

	if input:pressed("move_up") then
		menu:navigate(name, -1)
	end
	if input:pressed("move_down") then
		menu:navigate(name, 1)
	end

	if kind == "number" or kind == "enum" then
		local modified = false
		if input:pressed("move_left") then
			settings:adjust(option.label, -1)
			modified = true
		end
		if input:pressed("move_right") then
			settings:adjust(option.label, 1)
			modified = true
		end

		if modified then
			menu:refresh(name)
		end
	end
end

function flow:update(game_state)
	if game_state == "normal" then
		if input:pressed("pause") then
			self:set_state("paused")
		end
		return
	end

	if game_state == "paused" and input:pressed("pause") then
		self:set_state("normal")
		return
	end

	if game_state == "settings" and input:pressed("pause") then
		go_back()
		return
	end

	local name = menu_for_state[game_state]
	if name then
		handle_menu(self, name)
	end
end

return flow
