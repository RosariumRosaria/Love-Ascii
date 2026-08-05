return {
	window = {
		title = "Love Ascii",
		fullscreen = false,
		borderless = true,
		vsync = true,
		resizable = true,
	},
	map = {
		max_x = 750,
		max_y = 750,
		max_z = 10,
		min_z = -4,
		min_spawn_rooms = 5,
	},
	entities = {
		perception_brightness_threshold = 1.5,
	},
	timing = {
		frame_ai_budget = 2,
		turn_delay = 0.175,
		base_turn_cost = 100,
		day_length = 50000,
		time_keyframes = {
			{ at = 0.00, "night" },
			{ at = 0.25, "dawn" },
			{ at = 0.32, "day" },
			{ at = 0.78, "dusk" },
			{ at = 0.85, "night" },
		},
	},
	action_cost = {
		move = 1,
		attack = 1.25,
		ranged_attack = 1.25,
		interact = 1,
		pickup = 1,
		place = 1,
		drag = 2,
		use_item = 1,
		vault = 3,
		equip = 1,
		unequip = 1,
		wait = 1,
		transfer_item = 0.5,
	},
	pathfinding = {
		max_iterations = 2000,
		wait_cost = 4,
	},
	perf = {
		lag_warn_threshold = 0.033,
		warmup_frames = 30,
		warn_cooldown = 1,
		worst_frame_window = 5,
	},
	inventory = {
		max_stack_limit = 10,
	},

	event_log = {
		suppressed_types = {
			action_failed = false,
		},
	},

	prefab = nil,
}
