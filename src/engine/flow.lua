local input = require("src.engine.input")
local state = require("src.engine.state")
local menu = require("src.visuals.ui.menu")
local session = require("src.engine.session")
local entities = require("src.sim.entities")
local hud = require("src.visuals.ui.hud")
local flow = {}

local menu_for_state = { paused = "pause", start = "start", dead = "dead" }

function flow:set_state(new_state)
	local previous = state:get()
	if not state:set(new_state) then
		return false
	end
	local current = state:get()

	local leaving = previous ~= current and menu_for_state[previous]
	if leaving then
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
	if input:pressed("menu_interact") then
		local command = menu:get_option(name)
		if command == "RESPAWN" then
			session.respawn()
			self:set_state("normal")
		elseif command == "START" or command == "RESUME" then
			self:set_state("normal")
		elseif command == "RESTART" then
			session.reset()
			session.load()
			self:set_state("start")
		elseif command == "QUIT" then
			love.event.quit()
		end
	end

	if input:pressed("move_up") then
		menu:navigate(name, -1)
	end
	if input:pressed("move_down") then
		menu:navigate(name, 1)
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

	local name = menu_for_state[game_state]
	if name then
		handle_menu(self, name)
	end
end

return flow
