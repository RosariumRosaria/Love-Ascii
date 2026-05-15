local config = require("config.runtime")
local game_cfg = require("config.game_config")
local map = require("map.map")
local render = require("visuals.render.render")
local effects = require("visuals.effects.effects")
local ui = require("visuals.ui")
local input_handler = require("engine.input")
local visualizer = require("map.voronoi.visualizer")
local entities = require("entities.entities")
local turn = require("engine.turn")
local inventory = require("entities.inventory")
local stats = require("entities.stats")

function love.load()
	config:load()
	config:setup_window()

	render:reload_fonts()

	local map_max_x = game_cfg.map.max_x
	local map_max_y = game_cfg.map.max_y
	local map_max_z = game_cfg.map.max_z
	local map_min_z = game_cfg.map.min_z

	local player = entities:add_from_template("player", 20, 20, 1)
	entities:set_player(player)
	input_handler:set_actor(player)
	inventory.add_from_template(player, "sword")
	inventory.add_from_template(player, "leather_armor")
	inventory.add_from_template(player, "health_potion")
	inventory.equip(player, player.inventory.items[1])
	inventory.equip(player, player.inventory.items[2])
	entities:add_from_template("vampire", 5, 5, 1)
	entities:add_from_template("zombie", 8, 6, 1)
	entities:add_from_template("zombie", 7, 6, 1)
	entities:add_from_template("tree", 17, 14, 1)
	entities:add_from_template("crate", 10, 10, 1)
	entities:add_from_template("barricade", 15, 14, 1)
	entities:add_from_template("campfire", 12, 14, 1)
	entities:add_from_template("crystal", 46, 17, 1)
	entities:add_from_template("lantern", 24, 24, 1, { chars = { "8" } })
	entities:get_entity(24, 24, 1).item = inventory.create_item_from_template("torch", {
		name = "Lantern",
		key = "Lantern",
		chars = { "8" },
		light = {
			color = { r = 1.0, g = 0.85, b = 0.55 },
			flicker = { amp = 0.2, freq = 1, phase = 6 },
			intensity = 1,
			radius = 8,
		},
	})

	map:load(map_max_x, map_max_y, map_max_z, map_min_z, "town")
	map:update_visibility(entities.player.x, entities.player.y, stats.get_stat(entities.player, "sight"))
	ui:load()
	ui:update_status(entities.player)
	render:load(entities.player.x, entities.player.y)
end

function love.update(dt)
	turn:update(dt)
	render:update(entities.player.x, entities.player.y, dt)
	effects:update(dt)
end

function love.draw()
	render:draw()
	visualizer:draw()
end
