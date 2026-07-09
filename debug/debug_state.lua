local render_cfg = require("config.render_config")

local debug_state = {
	show_grid = render_cfg.debug.show_grid,
	bw_mode = render_cfg.debug.bw_mode,
	offset_type = render_cfg.rendering.default_offset_type,
	show_perf = false,
	show_xray = false,
	profiling = false,
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

function debug_state.toggle_perf()
	debug_state.show_perf = not debug_state.show_perf
end

function debug_state.toggle_xray()
	debug_state.show_xray = not debug_state.show_xray
end

return debug_state
