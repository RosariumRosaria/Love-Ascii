return {
	window = {
		title = "Love Ascii",
		fullscreen = false,
		borderless = true,
		vsync = true,
		resizable = true,
	},
	map = {
		max_x = 500,
		max_y = 500,
		max_z = 10,
		min_z = -4,
	},
	timing = {
		frame_ai_budget = 2,
		turn_delay = 0.2,
		base_turn_cost = 100,
		day_length = 10000,
		time_keyframes = {
			{ at = 0.00, "night" },
			{ at = 0.25, "dawn" },
			{ at = 0.32, "day" },
			{ at = 0.78, "dusk" },
			{ at = 0.85, "night" },
		},
	},
	pathfinding = {
		max_iterations = 1000,
		wait_cost = 5,
	},
	perf = {
		lag_warn_threshold = 0.1,
		warmup_frames = 30,
		warn_cooldown = 0.05,
		worst_frame_window = 5,
	},
}
