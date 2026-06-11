local config = require("config.runtime")
local game_cfg = require("config.game_config")
local map = require("map.map")
local scene = require("visuals.render.scene")
local effects = require("visuals.effects.effects")
local ui = require("visuals.ui")
local input_handler = require("engine.input")
local visualizer = require("debug.visualizer")
local entities = require("entities.entities")
local turn = require("engine.turn")
local inventory = require("items.inventory")
local stats = require("stats.stats")
local perf = require("engine.perf")

function love.load()
	config:load()
	config:setup_window()

	scene:reload_fonts()

	local map_max_x = game_cfg.map.max_x
	local map_max_y = game_cfg.map.max_y
	local map_max_z = game_cfg.map.max_z
	local map_min_z = game_cfg.map.min_z

	local player = entities.add_from_template("player", 250, 250, 1)
	entities.set_player(player)
	input_handler:set_actor(player)
	inventory.add_from_template(player, "sword")
	inventory.add_from_template(player, "bow")
	inventory.add_from_template(player, "leather_armor")
	inventory.add_from_template(player, "torch", {
		name = "Lantern",
		key = "Lantern",
		chars = { "8" },
		color = { { 1, 0.8, 0.6, 1 } },
		light = {
			color = { r = 1.0, g = 0.85, b = 0.65 },
			flicker = { amp = 0.1, freq = 2, phase = 6 },
			intensity = 0.5,
			radius = 8,
		},
	})
	inventory.add_from_template(player, "health_potion")
	inventory.add_from_template(player, "strength_potion")

	inventory.equip(player, player.inventory.items[1])
	inventory.equip(player, player.inventory.items[3])
	inventory.equip(player, player.inventory.items[4])
	entities.add_from_template("zombie", 256, 256, 1)
	entities.add_from_template("crate", 250, 260, 1)
	entities.add_from_template("barricade", 250, 255, 1)
	entities.add_from_template("campfire", 255, 260, 1)
	entities.add_from_template("crystal", 280, 255, 1)

	map:load(map_max_x, map_max_y, map_max_z, map_min_z, "town")
	map:update_visibility(entities.player.x, entities.player.y, stats.get(entities.player, "sight"))
	ui:load()
	ui:update_status(entities.player)
	scene:load(entities.player.x, entities.player.y)
end

function love.update(dt)
	perf:begin_frame()
	turn:update(dt)
	scene:update(dt)
	effects:update(dt)
end

function love.draw()
	scene:draw()
	visualizer:draw()
	perf:draw()
	perf:end_frame(ui)
end
