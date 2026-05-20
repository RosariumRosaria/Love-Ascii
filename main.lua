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
local inventory = require("items.inventory")
local stats = require("stats.stats")
local perf = require("engine.perf")

local TREE_TRUNK_COLOR = { 0.45, 0.32, 0.22, 1 }
local TREE_LEAF_COLOR = { 0.32, 0.5, 0.28, 1 }

local function make_tree_chars(height)
	local chars, colors = {}, {}
	for i = 1, height - 1 do
		chars[i] = "."
		colors[i] = TREE_TRUNK_COLOR
	end
	chars[height] = "*"
	colors[height] = TREE_LEAF_COLOR
	return chars, colors
end

function love.load()
	config:load()
	config:setup_window()

	render:reload_fonts()

	local map_max_x = game_cfg.map.max_x
	local map_max_y = game_cfg.map.max_y
	local map_max_z = game_cfg.map.max_z
	local map_min_z = game_cfg.map.min_z

	local player = entities.add_from_template("player", 100, 100, 1)
	entities.set_player(player)
	input_handler:set_actor(player)
	inventory.add_from_template(player, "sword")
	inventory.add_from_template(player, "bow")
	inventory.add_from_template(player, "leather_armor")
	inventory.add_from_template(player, "health_potion")
	inventory.add_from_template(player, "strength_potion")
	inventory.equip(player, player.inventory.items[1])
	inventory.equip(player, player.inventory.items[3])
	entities.add_from_template("vampire", 85, 95, 1)
	entities.add_from_template("zombie", 98, 86, 1)
	entities.add_from_template("zombie", 80, 96, 1)
	local copse_cx, copse_cy, copse_radius = 110, 100, 3
	for dy = -copse_radius, copse_radius do
		for dx = -copse_radius, copse_radius do
			if dx * dx + dy * dy <= copse_radius * copse_radius and math.random() < 0.6 then
				local height = math.random(4, 10)
				local chars, colors = make_tree_chars(height)
				entities.add_from_template("tree", copse_cx + dx, copse_cy + dy, 1, { chars = chars, color = colors })
			end
		end
	end
	entities.add_from_template("crate", 105, 100, 1)
	entities.add_from_template("barricade", 15, 14, 1)
	entities.add_from_template("campfire", 105, 105, 1)
	entities.add_from_template("crystal", 76, 77, 1)

	entities.add_pickup_from_template("torch", 111, 91, 1, {
		name = "Lantern",
		key = "Lantern",
		chars = { "8" },
		color = { { 1, 0.8, 0.6, 1 } },
		light = {
			color = { r = 1.0, g = 0.85, b = 0.55 },
			flicker = { amp = 0.1, freq = 2, phase = 6 },
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
	perf:begin_frame()
	turn:update(dt)
	render:update(dt)
	effects:update(dt)
end

function love.draw()
	render:draw()
	visualizer:draw()
	perf:draw()
	perf:end_frame(ui)
end
