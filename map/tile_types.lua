return {
	grass = {
		name = "grass",
		chars = { "." },
		walkable = true,
		color = { 0.2, 0.45, 0.25, 1 },
		transparent = true,
		covers = true,
	},

	shrub = {
		name = "shrub",
		chars = { "*" },
		walkable = true,
		color = { 0.35, 0.95, 0.35, 1 },
		transparent = true,
		covers = true,
		natural_height = 0.75,
	},

	v_wall = {
		name = "wall",
		chars = { "—" },
		walkable = false,
		color = { 0.65, 0.65, 0.7, 1 },
		transparent = false,
		natural_rotation = 0,
	},

	c_wall = {
		name = "wall",
		chars = { "+" },
		walkable = false,
		color = { 0.65, 0.65, 0.7, 1 },
		transparent = false,
	},

	water = {
		name = "water",
		chars = { "~" },
		walkable = false,
		color = { 0.2, 0.45, 0.75, 1 },
		transparent = true,
	},

	floor = {
		name = "floor",
		chars = { ":" },
		walkable = true,
		color = { 0.6, 0.5, 0.4, 1 },
		transparent = true,
		covers = true,
	},

	air = {
		name = "air",
		chars = { " " },
		walkable = false,
		color = { 0.9, 0.9, 1.0, 0.0 },
		transparent = true,
	},
}
