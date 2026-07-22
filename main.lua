local config = require("src.config.runtime")
local scene = require("src.visuals.render.scene")
local effects = require("src.visuals.effects.effects")
local panels = require("src.visuals.ui.panels")
local visualizer = require("src.debug.visualizer")
local turn = require("src.engine.turn")
local session = require("src.engine.session")
local input = require("src.engine.input")
local perf = require("src.engine.perf")
local state = require("src.engine.state")
local hud = require("src.visuals.ui.hud")
local debug_panel = require("src.debug.debug_panel")
local debug_input = require("src.debug.debug_input")

function love.load()
	config:load()
	config:setup_window()

	scene:reload_fonts()

	session.load()
end

function love.resize()
	scene:resize()
end

function love.update(dt)
	local game_state = state:get()
	perf:begin_frame()

	debug_input:update_global(input)
	if game_state == "normal" then
		input:update(dt)
		turn:update(dt)
	end

	if input:pressed("respawn") and game_state == "dead" then
		session.respawn()
	end

	if game_state == "paused" then
		if input:pressed("pause") then
			state:set("normal")
			hud:set_pause_visible(false)
		end

		if input:pressed("menu_interact") then
			local command = hud:get_pause_option()
			if command == "RESUME" then
				state:set("normal")
				hud:set_pause_visible(false)
			elseif command == "RESTART" then
				session.reset()
				session.load()
			elseif command == "QUIT" then
				love.event.quit()
			end
		end

		if input:pressed("move_up") then
			hud:update_pause_menu(-1)
		end
		if input:pressed("move_down") then
			hud:update_pause_menu(1)
		end
	end

	scene:update(dt)
	effects:update(dt)
	debug_panel.update()
	input:end_frame()
end

function love.draw()
	scene:draw()
	visualizer:draw()
	perf:draw()
	perf:end_frame(panels)
end
