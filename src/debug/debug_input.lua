local config = require("src.config.runtime")
local scene = require("src.visuals.render.scene")
local debug_state = require("src.debug.debug_state")
local visualizer = require("src.debug.visualizer")
local profiler = require("src.debug.profiler")
local event_log = require("src.engine.event_log")
local inventory = require("src.sim.inventory")
local entities = require("src.sim.entities")
local map = require("src.map.map")
local cursor = require("src.engine.interaction.cursor")
local prefab = require("src.map.prefab")
local game_cfg = require("src.config.game_config")

-- Debug-only keybinding handling, split out of src/engine/input.lua. `input` is
-- passed in rather than required, so this module stays off input's require cycle.
local debug_input = {}

local function debug_spawn()
	local mx, my = cursor.get_moused_coords()
	local entity_type = "skeleton"

	if map:is_tile_free(mx, my, 1) then
		entities.add_from_template(entity_type, mx, my, 1)
		event_log:add({ type = "debug", message = "spawned " .. entity_type })
		return
	end
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }
	for _, o in ipairs(offsets) do
		local x, y = mx + o[1], my + o[2]
		if map:is_tile_free(x, y, 1) then
			entities.add_from_template(entity_type, x, y, 1)

			event_log:add({ type = "debug", message = "spawned " .. entity_type })
			return
		end
	end
	event_log:add({ type = "debug", message = "no free cell to spawn " .. entity_type })
end

-- Render/inspection toggles: valid regardless of game state or whether there is
-- a player actor.
function debug_input:update_global(input)
	if input:pressed("toggle_grid") then
		debug_state.toggle_grid()
	end

	if input:pressed("toggle_bw") then
		debug_state.toggle_bw()
	end

	if input:pressed("toggle_profiler") then
		profiler:toggle()
	end

	if input:pressed("toggle_perf") then
		debug_state.toggle_perf()
	end

	if input:pressed("toggle_xray") then
		debug_state.toggle_xray()
	end

	if input:pressed("toggle_visualizer") then
		visualizer:toggle()
	end

	if input:pressed("toggle_font") then
		config:toggle_font()
		scene:reload_fonts()
	end

	if input:pressed("switch_offset") then
		debug_state.switch_offset()
	end
end

-- Toggles that touch the world or the player, so they only run while play is live.
function debug_input:update_actor(input, actor)
	-- Debug: re-read + re-stamp the configured prefab without restarting (map maker
	-- edit→save→tap-key loop). No-op unless game_config.prefab is set.
	if input:pressed("reload_prefab") and game_cfg.prefab then
		prefab.clear_last()
		prefab.stamp(game_cfg.prefab.file, game_cfg.prefab.ox, game_cfg.prefab.oy)
		map:update_visibility(actor)
		event_log:add({ type = "debug", message = "reloaded prefab" })
	end

	if input:pressed("debug") then
		local item = inventory.get_selected(actor)
		inventory.add_charge(item)
	end

	if input:pressed("debug_spawn_zombie") then
		debug_spawn()
	end
end

return debug_input
