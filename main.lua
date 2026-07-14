local config = require("config.runtime")
local game_cfg = require("config.game_config")
local map = require("map.map")
local scene = require("visuals.render.scene")
local effects = require("visuals.effects.effects")
local panels = require("visuals.panels")
local input_handler = require("engine.input")
local visualizer = require("debug.visualizer")
local entities = require("entities.entities")
local turn = require("engine.turn")
local inventory = require("items.inventory")
local stats = require("stats.stats")
local perf = require("engine.perf")
local statuses = require("statuses.statuses")
local prefab = require("map.prefab")

local debug_panel = require("debug.debug_panel")

local function load_default_inventory(player)
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
			radius = 10,
		},
	})

	inventory.equip(player, player.inventory.items[1])
	inventory.equip(player, player.inventory.items[3])
	inventory.equip(player, player.inventory.items[4])
end

local function load_chest_inventory(entity)
	inventory.add_from_template(entity, "planks")
	inventory.add_from_template(entity, "bandages")
	inventory.add_from_template(entity, "health_potion")
	inventory.add_from_template(entity, "strength_potion")
	inventory.add_from_template(entity, "splint")
end

local function apply_default_statuses(player)
	statuses.add_from_template(player, "bleeding")
	statuses.add_from_template(player, "broken_leg")
end

local function spawn_default_entities()
	entities.add_from_template_free("ogre", 262, 253, 1)
	entities.add_from_template_free("zombie", 256, 256, 1)
	entities.add_from_template_free("crate", 250, 260, 1)
	entities.add_from_template_free("barricade", 250, 255, 1)
	entities.add_from_template_free("campfire", 255, 260, 1)
	entities.add_from_template_free("crystal", 280, 255, 1)
	load_chest_inventory(entities.add_from_template_free("chest", 252, 251, 1))
end

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
	--apply_default_statuses(player)
	load_default_inventory(player)

	local prefab_cfg = game_cfg.prefab
	local map_type = (prefab_cfg and prefab_cfg.map_type) or "town"
	map:load(map_max_x, map_max_y, map_max_z, map_min_z, map_type)

	-- Prefab stamp (inert unless game_cfg.prefab is set — see config/game_config.lua).
	if prefab_cfg then
		local start = prefab.stamp(prefab_cfg.file, prefab_cfg.ox, prefab_cfg.oy)
		if start and prefab_cfg.move_player ~= false then
			entities.move_to(player, start.x, start.y, start.z)
		end
	end

	-- After the map (and any prefab) exist, so free-cell checks see real geometry.
	spawn_default_entities()

	map:update_visibility(entities.player.x, entities.player.y, stats.get(entities.player, "sight"))
	panels:load()
	panels:update_status(entities.player)
	scene:load(entities.player.x, entities.player.y)
	debug_panel.load()
end

function love.resize()
	scene:resize()
end

function love.update(dt)
	perf:begin_frame()
	turn:update(dt)
	scene:update(dt)
	effects:update(dt)
	debug_panel.update()
end

function love.draw()
	scene:draw()
	visualizer:draw()
	perf:draw()
	perf:end_frame(panels)
end
