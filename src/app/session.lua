local entities = require("src.sim.entities")
local inventory = require("src.sim.inventory")
local time = require("src.engine.time")
local cursor = require("src.engine.interaction.cursor")
local event_log = require("src.engine.event_log")
local input = require("src.engine.input")
local scene = require("src.visuals.render.scene")
local menu = require("src.visuals.ui.menu")
local hud = require("src.visuals.ui.hud")
local debug_panel = require("src.debug.debug_panel")
local effects = require("src.visuals.effects.effects")
local prefab = require("src.map.prefab")
local game_cfg = require("src.config.game_config")
local map = require("src.map.map")
local panels = require("src.visuals.ui.panels")
local particles = require("src.visuals.particles.particles")
local city_generator = require("src.map.city_generator")
local turn = require("src.engine.turn")
local session = {}

local FALLBACK_SPAWN = { x = 250, y = 250 }

local function spawn_default_entities()
	entities.add_from_template_free("crystal", 280, 255, 1)
end

function session.load(seed)
	seed = seed or os.time()
	love.math.setRandomSeed(seed)
	print("Seed: " .. seed)
	local map_max_x = game_cfg.map.max_x
	local map_max_y = game_cfg.map.max_y
	local map_max_z = game_cfg.map.max_z
	local map_min_z = game_cfg.map.min_z

	local prefab_cfg = game_cfg.prefab
	local map_type = (prefab_cfg and prefab_cfg.map_type) or "town"
	map:load(map_max_x, map_max_y, map_max_z, map_min_z, map_type)

	local spawn_room = city_generator:find_spawn_room(game_cfg.map.min_spawn_rooms)
	local spawn_x, spawn_y = FALLBACK_SPAWN.x, FALLBACK_SPAWN.y
	if spawn_room then
		spawn_x = math.floor(spawn_room.x + (spawn_room.w / 2))
		spawn_y = math.floor(spawn_room.y + (spawn_room.h / 2))
	end
	local phylactery = entities.add_from_template_free("phylactery", spawn_x, spawn_y, 1)
	local player = entities.add_from_template_free("player", phylactery.x, phylactery.y, 1)
	entities.set_player(player)
	entities.set_phylactery(phylactery)

	inventory.add_from_template(player, "dull_sword")
	inventory.add_from_template(player, "bow")
	inventory.add_from_template(player, "tunic")
	inventory.add_from_template(player, "torch", {
		name = "Lantern",
		key = "Lantern",
		chars = { "8" },
		color = { { 1, 0.8, 0.6, 1 } },
		light = {
			color = { r = 1.0, g = 0.9, b = 0.65 },
			flicker = { amp = 0.1, freq = 2, phase = 6 },
			intensity = 0.55,
			radius = 11,
		},
	})
	inventory.add_from_template(player, "plank")
	inventory.add_from_template(player, "bandage")
	inventory.add_from_template(player, "health_potion", { charges = 3 })
	inventory.add_from_template(player, "arrow", { charges = 3 })

	inventory.equip(player, player.inventory.items[1])
	inventory.equip(player, player.inventory.items[3])
	inventory.equip(player, player.inventory.items[4])
	input:set_actor(entities.player)

	if prefab_cfg then
		local start = prefab.stamp(prefab_cfg.file, prefab_cfg.ox, prefab_cfg.oy)
		if start and prefab_cfg.move_player ~= false then
			entities.move_to(entities.player, start.x, start.y, start.z)
		end
	end
	map:apply_on_step(entities.player)
	spawn_default_entities()
	map:update_visibility(entities.player)
	hud:load()
	hud:update_character(entities.player)
	scene:load(entities.player.x, entities.player.y)
	debug_panel.load()
	menu:load()
	input:reload_keys()
end

function session.respawn()
	local phylactery = entities.phylactery
	local player = entities.add_from_template_free("player", phylactery.x, phylactery.y, 1)
	entities.set_player(player)
	map:apply_on_step(entities.player)
	map:update_visibility(entities.player)
	input:set_actor(entities.player)
	input:set_mode("normal")
end

function session.reset()
	map:reset()
	entities.reset()
	input:reset()
	effects:reset()
	time.reset()
	cursor.reset()
	debug_panel.reset()
	event_log:reset()
	particles:reset()
	panels:reset()
	menu:reset()
	turn:reset()
end

return session
