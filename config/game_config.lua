return {
	window = {
		title = "Love Ascii",
		fullscreen = false,
		borderless = true,
		vsync = true,
		resizable = true,
	},
	map = {
		max_x = 300,
		max_y = 300,
		max_z = 10,
		min_z = -4,
	},
	timing = {
		turn_delay = 0.15,
		base_turn_cost = 100,
	},
	pathfinding = {
		max_iterations = 1000,
	},
	perf = {
		lag_warn_threshold = 0.1,
		warmup_frames = 30,
		warn_cooldown = 0.05,
	},
}
