return {
	wander_chance = 5, -- 1-in-N roll each idle tick
	wander_range = 10, -- +/- tiles from current position
	wander_turns = 20, -- countdown before giving up wander
	search_turns = 30,
	search_radius = 10,
	search_lead = 5,
	search_attempts = 8, -- tries to roll a walkable search probe before falling back to the vanish point
	activation_range = 50,
}
