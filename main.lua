local config = require("src.config.runtime")
local game_cfg = require("src.config.game_config")
local map = require("src.map.map")
local scene = require("src.visuals.render.scene")
local effects = require("src.visuals.effects.effects")
local panels = require("src.visuals.ui.panels")
local hud = require("src.visuals.ui.hud")
local visualizer = require("src.debug.visualizer")
local entities = require("src.sim.entities")
local turn = require("src.engine.turn")
local session = require("src.engine.session")
local input = require("src.engine.input")
local perf = require("src.engine.perf")
local prefab = require("src.map.prefab")
local state = require("src.engine.state")

local debug_panel = require("src.debug.debug_panel")

local function spawn_default_entities()
	entities.add_from_template_free("ogre", 262, 253, 1)
	entities.add_from_template_free("zombie", 256, 256, 1)
	entities.add_from_template_free("crate", 250, 260, 1)
	entities.add_from_template_free("barricade", 250, 255, 1)
	entities.add_from_template_free("campfire", 255, 260, 1)
	entities.add_from_template_free("crystal", 280, 255, 1)
end

function love.load()
	config:load()
	config:setup_window()

	scene:reload_fonts()

	local map_max_x = game_cfg.map.max_x
	local map_max_y = game_cfg.map.max_y
	local map_max_z = game_cfg.map.max_z
	local map_min_z = game_cfg.map.min_z

	session.load()
	input:set_actor(entities.player)

	local prefab_cfg = game_cfg.prefab
	local map_type = (prefab_cfg and prefab_cfg.map_type) or "town"
	map:load(map_max_x, map_max_y, map_max_z, map_min_z, map_type)

	-- Prefab stamp (inert unless game_cfg.prefab is set — see config/game_config.lua).
	if prefab_cfg then
		local start = prefab.stamp(prefab_cfg.file, prefab_cfg.ox, prefab_cfg.oy)
		if start and prefab_cfg.move_player ~= false then
			entities.move_to(entities.player, start.x, start.y, start.z)
		end
	end

	-- After the map (and any prefab) exist, so free-cell checks see real geometry.
	spawn_default_entities()

	map:update_visibility(entities.player)
	hud:load()
	hud:update_character(entities.player)
	scene:load(entities.player.x, entities.player.y)
	debug_panel.load()
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
