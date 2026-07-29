return {
	actor_cap = 100,

	max_spawn_tries = 20,
	max_path_checks = 5,

	spawn_list = {
		{ name = "zombie", price = 20, weight = 20 },
		{ name = "shambler", price = 20, weight = 20 },
		{ name = "skeleton", price = 30, weight = 6 },
		{ name = "vampire", price = 40, weight = 6 },
		{ name = "ogre", price = 60, weight = 1 },
	},

	modifiers = {
		{ name = "normal", price = 0, weight = 30 },
		{ name = "hunter", price = 10, weight = 5 },
	},

	pack_sizes = {
		{ size = 1, weight = 10 },
		{ size = 2, weight = 5 },
		{ size = 3, weight = 1 },
	},

	-- distance band from the player for the pack leader
	min_spawn_range = 20,
	max_spawn_range = 50,
	-- distance band from the leader for the rest of the pack
	min_pack_spawn_range = 1,
	max_pack_spawn_range = 10,

	-- dread accrues each tick and is spent on packs
	dread_inc = 1,
	min_dread_spawn = 40,
	max_dread_spawn = 200,
	-- percent chance of a spawn attempt, lerped across the dread band
	min_spawn_chance = 1,
	max_spawn_chance = 100,
}
