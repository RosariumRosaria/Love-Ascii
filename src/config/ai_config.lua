local game_cfg = require("src.config.game_config")

return {
	wander_chance = 5,
	wander_range = 10,
	wander_turns = 20,
	search_turns = 20,
	search_radius = 10,
	search_lead = 5,
	search_attempts = 8,
	activation_range = 50,
	investigate_turns = 20,
	perception_brightness_threshold = 1.5,
	unlit_sight_scale = 0.5,
	chase_sight_value = 1.5,
	avoid = {
		-- packs (x, y) into one key via y + x*stride; must exceed max y to avoid collisions
		stride = game_cfg.map.max_y + 1,
		cap = 50,
		inc = 3,
	},

	target_value = {
		wander = 3,
		search = 4,
		investigate = 4,
		sight = 7,
	},
}
