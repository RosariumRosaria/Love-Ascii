local input = require("src.engine.input")
local state = require("src.engine.state")
local menu = require("src.visuals.ui.menu")
local session = require("src.engine.session")
local entities = require("src.sim.entities")
local hud = require("src.visuals.ui.hud")
local screens = {}

local function handle_menu(name)
	if input:pressed("menu_interact") then
		local command = menu:get_option(name)
		if command == "RESPAWN" then
			session.respawn()
			menu:set_visible(name, false)
		elseif command == "START" then
			state:set("normal")
			menu:set_visible(name, false)
		elseif command == "RESUME" then
			state:set("normal")
			menu:set_visible(name, false)
		elseif command == "RESTART" then
			session.reset()
			session.load()
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

function screens:update(game_state)
	if game_state == "paused" then
		if input:pressed("pause") then
			state:set("normal")
			menu:set_visible("pause", false)
		end
		handle_menu("pause")
	elseif game_state == "start" then
		menu:set_visible("start", true)
		handle_menu("start")
	elseif game_state == "dead" then
		menu:set_death_reason("Killed by a " .. (entities.player.death_source or "Unknown"))
		menu:set_visible("dead", true)
		handle_menu("dead")
	elseif game_state == "normal" then
		if input:pressed("pause") then
			state:set("paused")
			menu:set_visible("pause", true)
		end
	end

	hud:set_visible(state:get() == "normal")
end

return screens
