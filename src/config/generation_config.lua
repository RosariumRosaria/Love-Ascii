return {

	road_skip_chance = 15,

	lot_min_size = 10,
	lot_max_size = 20,
	lot_stop_chance = 0.55,

	subdivide_depth = 10,
	building_margin = 4,
	min_building_size = 6,
	building_chance = 0.75,
	second_door_chance = 0.75,
	road_side_door_weight = 7,

	shrub_chance = 0.02,

	scale = 0.125,
	jitter = 0.15,
	-- how far the noise field pushes the treeline in and out, in wildness units
	noise_strength = 1,
	-- where each band starts, and how much wildness above that it takes to reach
	-- full density: wider ramp = softer, patchier fade from the band's centre to its edge
	shrub_threshold = 0.7,
	shrub_ramp = 0.5,
	tree_threshold = 0.9,
	tree_ramp = 0.4,
	canopy_density = 0.67,

	-- tiles from the nearest road/building at which wildness saturates at 1
	civ_falloff = 12,

	monster_chance = 0.002,
	monsters = {
		{ name = "zombie", weight = 10 },
		{ name = "shambler", weight = 10 },
		{ name = "vampire", weight = 2 },
		{ name = "skeleton", weight = 2 },
		{ name = "ogre", weight = 1 },
	},

	lamp_step = 30,
	lamp_skip_chance = 0.85,
}
