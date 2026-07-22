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

local debug_panel = require("src.debug.debug_panel")

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
	perf:begin_frame()
	input:update(dt)
	if state:get() == "normal" then
		turn:update(dt)
	end

	if input:pressed("respawn") and state:get() == "dead" then
		session.respawn()
	end

	if input:pressed("reset") then
		session.reset()
		session.load()
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
