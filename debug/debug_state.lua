local render_cfg = require("config.render_config")

local debug_state = {
	show_grid = render_cfg.show_grid,
	bw_mode = render_cfg.bw_mode,
	offset_type = render_cfg.default_offset_type,
	normalize_lighting = true,
	show_perf = false,
}

function debug_state.toggle_grid()
	debug_state.show_grid = not debug_state.show_grid
end

function debug_state.toggle_bw()
	debug_state.bw_mode = (debug_state.bw_mode + 1) % 3
end

function debug_state.switch_offset()
	debug_state.offset_type = (debug_state.offset_type % 3) + 1
end

function debug_state.toggle_normalize_lighting()
	debug_state.normalize_lighting = not debug_state.normalize_lighting
end

function debug_state.toggle_perf()
	debug_state.show_perf = not debug_state.show_perf
end

return debug_state
