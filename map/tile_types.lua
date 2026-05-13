return {
	grass = {
		name = "Grass",
		chars = { "." },
		walkable = true,
		color = { 0.33, 0.85, 0.33, 1 },
		transparent = true,
		covers = true,
	},

	shrub = {
		name = "Shrub",
		chars = { "*" },
		walkable = true,
		color = { 0.35, 0.95, 0.35, 1 },
		transparent = true,
		covers = true,
		applies_status = { "obscured" },
		natural_height = 0.75,
	},

	v_wall = {
		name = "Wall",
		chars = { "|" },
		walkable = false,
		color = { 0.65, 0.65, 0.7, 1 },
		transparent = false,
		natural_rotation = 90,
	},

	c_wall = {
		name = "Pillar",
		chars = { "+" },
		walkable = false,
		color = { 0.65, 0.65, 0.7, 1 },
		transparent = false,
	},

	water = {
		name = "Water",
		chars = { "~" },
		walkable = false,
		color = { 0.2, 0.45, 0.75, 1 },
		transparent = true,
	},

	floor = {
		name = "Floor",
		chars = { ":" },
		walkable = true,
		color = { 0.6, 0.5, 0.4, 1 },
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
