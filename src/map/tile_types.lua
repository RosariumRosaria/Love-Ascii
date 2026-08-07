return {
	grass = {
		name = "Grass",
		chars = { "." },
		walkable = true,

		color = { 0.48, 0.60, 0.44, 1 },
		transparent = true,
		covers = true,
	},

	tree_trunk = {
		name = "Tree",
		chars = { "." },
		walkable = false,
		color = { 0.30, 0.23, 0.17, 1 },
		transparent = false,
		covers = false,
	},

	tree_leaves = {
		name = "Tree",
		chars = { "*" },
		walkable = false,
		color = { 0.26, 0.34, 0.24, 1 },
		transparent = false,
		covers = false,
	},

	shrub = {
		name = "Shrub",
		chars = { "*" },
		walkable = true,
		color = { 0.38, 0.50, 0.34, 1 },
		transparent = true,
		covers = true,
		applies_status = { "obscured", silent = true },
		natural_height = 0.35,
	},
	road = {
		name = "Road",
		chars = { "%" },
		walkable = true,

		color = { 0.44, 0.38, 0.30, 1 },

		transparent = true,
		covers = true,
	},

	v_wall = {
		name = "Wall",
		chars = { "|" },
		walkable = false,
		color = { 0.84, 0.78, 0.71, 1 },
		transparent = false,
		natural_rotation = 90,
	},

	h_wall = {
		name = "Wall",
		chars = { "|" },
		walkable = false,
		color = { 0.84, 0.78, 0.71, 1 },
		transparent = false,
		natural_rotation = 90,
		rotation = 90,
	},

	c_wall = {
		name = "Pillar",
		chars = { "+" },
		walkable = false,
		color = { 0.34, 0.26, 0.20, 1 },
		transparent = false,
	},

	v_stone_wall = {
		name = "Wall",
		chars = { "=" },
		walkable = false,
		color = { 0.1, 0.275, 0.55, 1 },
		transparent = false,
	},

	h_stone_wall = {
		name = "Wall",
		chars = { "=" },
		walkable = false,
		color = { 0.1, 0.275, 0.55, 1 },
		transparent = false,
		rotation = 90,
	},

	water = {
		name = "Water",
		chars = { "~" },
		walkable = false,
		color = { 0.3, 0.55, 0.95, 1 },
		transparent = true,
	},

	floor = {
		name = "Floor",
		chars = { ":" },
		walkable = true,
		color = { 0.34, 0.37, 0.41, 1 },
		transparent = true,
		covers = true,
	},

	air = {
		name = "Air",
		chars = { " " },
		walkable = false,
		color = { 0.9, 0.9, 1.0, 0.0 },
		transparent = true,
	},
}
