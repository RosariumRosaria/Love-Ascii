return {

	-- Binary-space subdivision of the map into lots + the roads between them
	lots = {
		min_size = 12,
		max_size = 17,
		stop_chance = 0.55,
		subdivide_depth = 11,
	},

	roads = {
		skip_chance = 15,
		lamp_step = 30,
		lamp_skip_chance = 0.85,
	},

	-- Building footprint carved out of a lot
	buildings = {
		chance = 0.75,
		margin = 4,
		min_size = 10,
		max_aspect = 1.5,
		wing_chance = 0.5,
	},

	-- Interior subdivision of a footprint into rooms
	rooms = {
		min_thickness = 5,
		max_size = 12,
		split_chance = 0.5,
		max_split_depth = 2,
	},

	doors = {
		second_chance = 0.75,
		road_side_weight = 7,
		open_internal_chance = 0.5,
	},

	windows = {
		door_gap = 1,
	},

	-- Distance-from-civilization field + noise that drives wild growth
	noise = {
		scale = 0.125,
		strength = 1,
		jitter = 0.15,
		civ_falloff = 12,
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
