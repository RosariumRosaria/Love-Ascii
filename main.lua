local config = require("src.config.runtime")
local scene = require("src.visuals.render.scene")
local effects = require("src.visuals.effects.effects")
local panels = require("src.visuals.ui.panels")
local visualizer = require("src.debug.visualizer")
local turn = require("src.engine.turn")
local session = require("src.app.session")
local input = require("src.engine.input")
local perf = require("src.engine.perf")
local state = require("src.app.state")
local flow = require("src.app.flow")
local hud = require("src.visuals.ui.hud")
local debug_panel = require("src.debug.debug_panel")
local debug_input = require("src.debug.debug_input")
local settings = require("src.config.settings")

function love.load()
	settings:load()
	settings:load_keybinds()
	config:load()
	config:setup_window()
	scene:reload_fonts()
	session.load()

	flow:set_state("start")
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
		hud:update()
	end

	flow:update(game_state)
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
