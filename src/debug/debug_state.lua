local render_cfg = require("src.config.render_config")

local debug_state = {
	show_grid = render_cfg.debug.show_grid,
	bw_mode = render_cfg.debug.bw_mode,
	offset_type = render_cfg.rendering.default_offset_type,
	show_perf = false,
	-- tints cells whose sky exposure is 0, i.e. cells the ambient sky never reaches
	show_sky_mask = false,
	-- 0 = off, 1 = entities, 2 = entities + tiles
	show_xray = 0,
	profiling = false,
	-- prints map-generation warnings (sealed rooms, …) to the launching terminal
	log_generation = true,
	-- pushes a debug event when a_star gives up at its iteration cap
	log_pathfinding = true,
	-- pushes a debug event naming each pack the director spawns
	log_director = true,
}

function debug_state.toggle_grid()
	debug_state.show_grid = not debug_state.show_grid
end

function debug_state.toggle_sky_mask()
	debug_state.show_sky_mask = not debug_state.show_sky_mask
end

function debug_state.toggle_bw()
	debug_state.bw_mode = (debug_state.bw_mode + 1) % 3
end

function debug_state.switch_offset()
	debug_state.offset_type = (debug_state.offset_type % 3) + 1
end

function debug_state.toggle_perf()
	debug_state.show_perf = not debug_state.show_perf
end

function debug_state.toggle_xray()
	debug_state.show_xray = (debug_state.show_xray + 1) % 3
end

return debug_state
