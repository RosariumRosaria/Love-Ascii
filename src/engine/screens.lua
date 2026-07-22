local input = require("src.engine.input")
local state = require("src.engine.state")
local panels = require("src.visuals.ui.panels")
local menu = require("src.visuals.ui.menu")
local session = require("src.engine.session")
local entities = require("src.sim.entities")
local hud = require("src.visuals.ui.hud")
local screens = {}

function screens:update(game_state)
	if game_state == "paused" then
		if input:pressed("pause") then
			state:set("normal")
			menu:set_pause_visible(false)
		end
		if input:pressed("menu_interact") then
			local command = menu:get_pause_option()
			if command == "RESUME" then
				state:set("normal")
				menu:set_pause_visible(false)
			elseif command == "RESTART" then
				session.reset()
				session.load()
			elseif command == "QUIT" then
				love.event.quit()
			end
		end

		if input:pressed("move_up") then
			menu:update_pause_menu(-1)
		end
		if input:pressed("move_down") then
			menu:update_pause_menu(1)
		end
	elseif game_state == "start" then
		menu:set_start_visible(true)
		if input:pressed("menu_interact") then
			local command = menu:get_start_option()
			if command == "START" then
				state:set("normal")
				menu:set_start_visible(false)
			elseif command == "QUIT" then
				love.event.quit()
			end
		end

		if input:pressed("move_up") then
			menu:update_start_menu(-1)
		end
		if input:pressed("move_down") then
			menu:update_start_menu(1)
		end
	elseif game_state == "dead" then
		panels:get_panel("death_reason").texts = { "Killed by a " .. entities.player.death_source }
		menu:set_dead_visible(true)
		if input:pressed("menu_interact") then
			local command = menu:get_dead_option()
			if command == "RESPAWN" then
				session.respawn()
				menu:set_dead_visible(false)
			elseif command == "RESTART" then
				session.reset()
				session.load()
			elseif command == "QUIT" then
				love.event.quit()
			end
		end
		if input:pressed("move_up") then
			menu:update_dead_menu(-1)
		end
		if input:pressed("move_down") then
			menu:update_dead_menu(1)
		end
	end
	hud:set_visible(game_state == "normal")
end

return screens
