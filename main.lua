local config = require("config")
local game_cfg = require("config.game_config")
local map = require("map.map")
local render_handler = require("visuals.render_handler")
local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local input_handler = require("engine.input_handler")
local visualizer = require("voroni.visualizer")
local entities = require("entities.entities")
local turn_handler = require("engine.turn_handler")

function love.load()
	config:load()
	config:setup_window()

	render_handler:reload_fonts()

	local map_max_x = game_cfg.map.max_x
	local map_max_y = game_cfg.map.max_y
	local map_max_z = game_cfg.map.max_z
	local map_min_z = game_cfg.map.min_z

	local player = entities:add_from_template("player", 20, 20, 1)
	entities:set_player(player)
	input_handler:set_actor(player)

	entities:add_from_template("vampire", 5, 5, 1)
	entities:add_from_template("vampire", 8, 6, 1)
	entities:add_from_template("crate", 10, 10, 1)
	entities:add_from_template("barricade", 15, 14, 1)

	map:load(map_max_x, map_max_y, map_max_z, map_min_z, "town")
	map:update_visibility(entities.player.x, entities.player.y, entities.player.stats.sight.sight)

	ui_handler:load()
	ui_handler:update_status(entities.player)
	render_handler:load(entities.player.x, entities.player.y)
end

function love.update(dt)
	turn_handler:update(dt)
	render_handler:update(entities.player.x, entities.player.y, dt)
	visuals:update(dt)
end

function love.draw()
	render_handler:draw()
	visualizer:draw()
end
