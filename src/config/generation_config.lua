return {
	wards = {
		river_width = 10,
		arterial_width = 5,
		ward_count = 4,
	},

	lots = {
		min_size = 17,
		max_size = 36,
		stop_chance = 0.4,
		subdivide_depth = 12,
	},

	roads = {
		skip_chance = 0.1,
		lamp_step = 40,
		lamp_skip_chance = 0.75,
		wave_amp = 1.5,
		wave_scale = 0.06,
		envelope = 5,
	},

	buildings = {
		chance = 0.75,
		margin = 5,
		min_size = 10,
		max_aspect = 1.5,
		min_coverage = 0.55,
		max_coverage = 0.85,
		wing_chance = 0.5,
		spawn_center_bias = 5,
	},

	rooms = {
		min_thickness = 5,
		max_size = 12,
		split_chance = 0.4,
		max_split_depth = 3,
	},

	doors = {
		second_chance = 0.75,
		road_side_weight = 7,
		open_internal_chance = 0.5,
		min_loops = 0,
		max_loops = 2,
	},

	windows = {
		door_gap = 1,
	},

	noise = {
		scale = 0.125,
		strength = 1.2,
		jitter = 0.2,
		civ_falloff = 11,
	},

	flora = {
		shrub_chance = 0.02,
		shrub_threshold = 0.7,
		shrub_ramp = 0.5,
		tree_threshold = 0.9,
		tree_ramp = 0.4,
		canopy_density = 0.67,
	},

	monsters = {
		chance = 0.002,
		types = {
			{ name = "zombie", weight = 10 },
			{ name = "shambler", weight = 10 },
			{ name = "vampire", weight = 2 },
			{ name = "skeleton", weight = 2 },
			{ name = "ogre", weight = 1 },
		},
	},
}
