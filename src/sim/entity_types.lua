local WOOD_DARK = { 0.26, 0.20, 0.15, 1 }
local WOOD = { 0.42, 0.33, 0.25, 1 }
local WOOD_LIGHT = { 0.55, 0.43, 0.34, 1 }

return {
	--------------------------------------------------------------------------
	-- ACTORS
	--------------------------------------------------------------------------

	player = {
		name = "Player",
		type = "actor",
		team = "player",
		natural_height = 0.25,
		natural_rotation = 270,
		mirror_facing = true,
		appearance = {
			chars = { "@" },
			color = { { 0.8, 0.8, 0.9, 1 } },
			text_color = { 1, 1, 1, 1 },
			effect_color = { 0.45, 0.45, 0.5, 0.5 },
		},
		default_action = "attackable",
		can_perform = {
			attackable = true,
			moveable = true,
			interactable = true,
			pickupable = true,
			vaultable = true,
		},
		tags = { covers = true, attackable = true, can_hear = true },
		combat = { hit_burst = "blood" },
		natural_weapon = "fists",
		stats = {
			health = { base = 20, current = 20 },
			stamina = { base = 10, current = 10 },
			hunger = { base = 10, current = 10 },
			sight = { base = 30 },
			stealth = { base = 10 },
			speed = { base = 5 },
			accuracy = { base = 5 },
			evasion = { base = 5 },
			strength = { base = 1 },
			damage = { base = 0 },
			damage_spread = { base = 0 },
		},
	},

	zombie = {
		name = "Zombie",
		description = "A zombie, try attacking it!",
		type = "actor",
		team = "enemy",
		mind = { state = "idle" },
		natural_height = 0.25,
		appearance = {
			chars = { "Z" },
			color = { { 0.3, 0.45, 0.25, 1 } },
			text_color = { 0.3, 0.45, 0.25, 1 },
			effect_color = { 0.35, 0.6, 0.3, 0.5 },
		},
		loot = {
			count = { min = 0, max = 1 },
			drops = {
				{ item = "bandage", weight = 10 },
			},
		},
		default_action = "attackable",
		can_perform = {
			attackable = true,
			vaultable = true,
		},
		tags = {
			moveable = true,
			covers = true,
			attackable = true,
			can_hear = true,
		},
		combat = {
			hit_burst = "blood",
		},
		natural_weapon = "rotting_hands",
		stats = {
			health = { base = 10, current = 10 },
			sight = { base = 30 },
			speed = { base = 4 },
			accuracy = { base = 4 },
			evasion = { base = 4 },
			damage = { base = 0 },
			damage_spread = { base = 0 },
		},
	},

	shambler = {
		name = "Shambler",
		description = "A shambler, try attacking it!",
		type = "actor",
		team = "enemy",
		mind = { state = "idle" },
		natural_height = 0.25,
		appearance = {
			chars = { "S" },
			color = { { 0.4, 0.48, 0.38, 1 } },
			text_color = { 0.4, 0.48, 0.38, 1 },
			effect_color = { 0.48, 0.56, 0.45, 0.5 },
		},
		default_action = "attackable",
		can_perform = {
			attackable = true,
		},
		tags = {
			moveable = true,
			covers = true,
			attackable = true,
			can_hear = true,
		},
		combat = {
			hit_burst = "blood",
		},
		natural_weapon = "blighted_claws",
		stats = {
			health = { base = 10, current = 10 },
			sight = { base = 30 },
			speed = { base = 4 },
			accuracy = { base = 4 },
			evasion = { base = 3 },
			damage = { base = 0 },
			damage_spread = { base = 0 },
		},
	},

	skeleton = {
		name = "skeleton",
		description = "A skeleton, try attacking it!",
		type = "actor",
		team = "enemy",
		mind = { state = "idle" },
		natural_height = 0.25,
		appearance = {
			chars = { "S" },
			color = { { 0.72, 0.65, 0.6, 1 } },
			text_color = { 0.72, 0.65, 0.6, 1 },
			effect_color = { 0.65, 0.61, 0.51, 0.5 },
		},
		loot = {
			guaranteed = {
				{ item = "bow", equip = true },
			},
			count = { min = 1, max = 5 },
			drops = {
				{ item = "arrow", equip = true, weight = 10 },
			},
		},
		default_action = "attackable",
		can_perform = {
			attackable = true,
		},
		tags = {
			moveable = true,
			covers = true,
			attackable = true,
			night_vision = true,
			can_hear = true,
			windup = true,
		},
		combat = {
			hit_burst = "dust",
		},
		natural_weapon = "bone_claws",
		stats = {
			health = { base = 6, current = 6 },
			sight = { base = 25 },
			speed = { base = 4 },
			accuracy = { base = 6 },
			evasion = { base = 3 },
			strength = { base = 1 },
			damage = { base = 0 },
			damage_spread = { base = 0 },
		},
	},

	vampire = {
		name = "Vampire",
		description = "A vampire, try attacking it!",
		type = "actor",
		team = "enemy",
		mind = { state = "idle" },
		natural_height = 0.25,
		appearance = {
			chars = { "V" },
			color = { { 0.58, 0.11, 0.15, 1 } },
			text_color = { 0.58, 0.11, 0.15, 1 },
			effect_color = { 0.30, 0.06, 0.08, 0.5 },
		},
		default_action = "attackable",
		can_perform = {
			attackable = true,
			interactable = true,
			vaultable = true,
		},
		tags = {
			moveable = true,
			covers = true,
			attackable = true,
			night_vision = true,
			can_hear = true,
		},
		combat = {
			hit_burst = "blood",
		},
		natural_weapon = "fangs",
		stats = {
			health = { base = 10, current = 10 },
			sight = { base = 30 },
			speed = { base = 6 },
			accuracy = { base = 6 },
			evasion = { base = 6 },
			damage = { base = 0 },
			damage_spread = { base = 0 },
		},
	},

	ogre = {
		name = "Ogre",
		description = "An ogre, try attacking it!",
		type = "actor",
		team = "enemy",
		mind = { state = "idle" },
		natural_height = 0.25,
		appearance = {
			chars = { "O" },
			color = { { 0.72, 0.55, 0.2, 1 } },
			text_color = { 0.72, 0.55, 0.2, 1 },
			effect_color = { 0.8, 0.62, 0.23, 0.5 },
		},
		footprint = {
			{ dx = 0, dy = 0, char = "O" },
			{ dx = 1, dy = 0, char = "G" },
			{ dx = 0, dy = 1, char = "R" },
			{ dx = 1, dy = 1, char = "E" },
		},
		default_action = "attackable",
		can_perform = {
			attackable = true,
		},
		tags = {
			moveable = true,
			covers = true,
			attackable = true,
			can_hear = true,
		},
		combat = {
			hit_burst = "blood",
		},
		natural_weapon = "massive_fists",
		stats = {
			health = { base = 30, current = 30 },
			sight = { base = 30 },
			speed = { base = 3 },
			accuracy = { base = 3 },
			evasion = { base = 3 },
			damage = { base = 0 },
			damage_spread = { base = 0 },
		},
	},

	dragon = {
		name = "Dragon",
		description = "A dragon, try attacking it!",
		type = "actor",
		team = "enemy",
		mind = { state = "idle" },
		natural_height = 0.25,
		appearance = {
			chars = { "D" },
			color = { { 0.74, 0.28, 0.14, 1 } },
			text_color = { 0.74, 0.28, 0.14, 1 },
			effect_color = { 0.70, 0.24, 0.10, 0.4 },
		},
		footprint = {
			{ dx = 0, dy = 0, char = "R" },
			{ dx = 1, dy = 0, char = "E" },
			{ dx = 2, dy = 0, char = "D" },
			{ dx = 0, dy = 1, char = "D" },
			{ dx = 1, dy = 1, char = "R" },
			{ dx = 2, dy = 1, char = "A" },
			{ dx = 0, dy = 2, char = "G" },
			{ dx = 1, dy = 2, char = "O" },
			{ dx = 2, dy = 2, char = "N" },
		},
		default_action = "attackable",
		can_perform = {
			attackable = true,
		},
		tags = {
			moveable = true,
			covers = true,
			attackable = true,
			can_hear = true,
		},
		combat = {
			hit_burst = "blood",
		},
		natural_weapon = "burning_maw",
		stats = {
			health = { base = 30, current = 30 },
			sight = { base = 30 },
			speed = { base = 5 },
			accuracy = { base = 6 },
			evasion = { base = 6 },
			damage = { base = 0 },
			damage_spread = { base = 0 },
		},
	},

	--------------------------------------------------------------------------
	-- PROPS: containers
	--------------------------------------------------------------------------

	corpse = {
		name = "Corpse",
		description = "A corpse, try interacting with it!",
		type = "prop",
		appearance = {
			chars = { "C" },
			color = { { 0.2, 0.2, 0.2 } },
			text_color = { 0.2, 0.2, 0.2, 1 },
		},
		inventory = {
			items = {},
			equipped = { armor = nil, offhand = nil, accessory = nil, mainhand = nil },
			selected_index = nil,
		},
		interact_priority = 1, -- outranks a door/window it happens to be lying on
		tags = {
			walkable = true,
			container = true,
			covers = true,
			interactable = true,
			moveable = true,
			attackable = true,
		},
		stats = {
			health = { base = 1, current = 1 },
			evasion = { base = 0 },
		},
	},

	chest = {
		name = "Chest",
		description = "A chest, try interacting with it!",
		type = "prop",
		appearance = {
			chars = { "[]", "[]" },
			color = { WOOD_DARK, WOOD_LIGHT },
			text_color = WOOD_LIGHT,
		},
		loot = {
			count = { min = 1, max = 4 },
			drops = {
				{ item = "health_potion", weight = 2 },
				{ item = "bandage", weight = 10 },
				{ item = "strength_potion", weight = 1 },
				{ item = "plank", weight = 5 },
			},
		},
		inventory = {
			items = {},
			equipped = { armor = nil, offhand = nil, accessory = nil, mainhand = nil },
			selected_index = nil,
		},
		default_action = "moveable",
		interact_priority = 1,
		tags = {
			moveable = true,
			tilelike = true,
			covers = true,
			attackable = true,
			interactable = true,
			container = true,
		},
		combat = { hit_burst = "dust" },
		stats = {
			health = { base = 5, current = 5 },
			evasion = { base = 0 },
		},
	},

	--------------------------------------------------------------------------
	-- PROPS: structures (doors, windows, barricades)
	--------------------------------------------------------------------------

	door = {
		name = "Door",
		description = "A door, try opening it!",
		type = "prop",
		natural_rotation = 0,
		appearance = {
			chars = { "[", "[" },
			color = { WOOD },
			text_color = WOOD,
		},
		passage = { kind = "walkable" },
		interaction = {
			requires_empty = true,
			toggle = {
				natural_rotation = 0,
				appearance = {
					chars = { ":", ":" },
				},
				tags = {
					solid = false,
					walkable = true,
					barricadeable = false,
				},
			},
		},
		corpse = "broken_door",
		default_action = "interactable",
		tags = {
			solid = true,
			walkable = false, -- swapped by interaction.toggle; must stay explicit
			tilelike = true,
			interactable = true,
			attackable = true,
			barricadeable = true,
		},
		combat = { hit_burst = "dust" },
		stats = {
			health = { base = 30, current = 30 },
			evasion = { base = 0 },
		},
	},

	window = {
		name = "Window",
		description = "A window, try opening it!",
		type = "prop",
		natural_rotation = 90,
		appearance = {
			chars = { " ", "-", "-" },
			color = { WOOD_LIGHT, WOOD, WOOD },
			text_color = WOOD_LIGHT,
		},
		corpse = "broken_window",
		passage = { kind = "vaultable" },
		interaction = {
			toggle = {
				appearance = {
					chars = { " ", "''", "''" },
				},
				default_action = "vaultable",
				natural_rotation = 90,
				tags = {
					solid = false,
					walkable = false,
					barricadeable = false,
					vaultable = true,
					attackable = true,
				},
			},
		},
		default_action = "interactable",
		tags = {
			solid = true,
			walkable = false,
			tilelike = true,
			interactable = true,
			vaultable = false,
			barricadeable = true,
			attackable = true,
		},
		combat = { hit_burst = "dust" },
		stats = {
			health = { base = 20, current = 20 },
			evasion = { base = 0 },
		},
	},

	broken_window = {
		name = "Broken Window",
		description = "A broken window, try climbing through it!",
		type = "prop",
		natural_rotation = 90,
		appearance = {
			chars = { " ", "'", "'" },
			color = { WOOD_LIGHT, WOOD, WOOD },
			text_color = WOOD_LIGHT,
		},
		interaction = {
			requires_empty = true,
			cost = { item = "plank", action_cost = 2 },
			replace = "window",
		},
		passage = { kind = "vaultable" },
		default_action = "vaultable",
		tags = {
			solid = false,
			walkable = false,
			tilelike = true,
			interactable = true,
			vaultable = true,
		},
	},
	broken_door = {
		name = "Broken Door",
		description = "A broken door, try climbing through it!",
		type = "prop",
		natural_rotation = 90,
		appearance = {
			chars = { "-", "-" },
			color = { WOOD },
			text_color = WOOD,
		},
		interaction = {
			requires_empty = true,
			cost = { item = "plank", action_cost = 3 },
			replace = "door",
		},
		passage = { kind = "walkable" },
		tags = {
			interactable = true,
			solid = false,
			walkable = true,
			tilelike = true,
		},
	},

	barricade = {
		name = "Barricade",
		description = "A heavy barricade, try pushing it!",
		type = "prop",
		appearance = {
			chars = { "X", "X" },
			color = { WOOD_DARK, WOOD },
			text_color = WOOD_LIGHT,
		},
		default_action = "moveable",
		tags = {
			solid = true,
			moveable = true,
			tilelike = true,
			covers = true,
			attackable = true,
		},
		combat = { hit_burst = "dust" },
		stats = {
			health = { base = 20, current = 20 },
			evasion = { base = 0 },
		},
	},

	crate = {
		name = "Crate",
		description = "A heavy crate, try pushing it!",
		type = "prop",
		appearance = {
			chars = { "#", "#" },
			color = { WOOD_DARK, WOOD_LIGHT },
			text_color = WOOD_LIGHT,
		},
		default_action = "moveable",
		tags = {
			moveable = true,
			tilelike = true,
			covers = true,
			attackable = true,
		},
		combat = { hit_burst = "dust" },
		stats = {
			health = { base = 5, current = 5 },
			evasion = { base = 0 },
		},
	},

	barrel = {
		name = "Barrel",
		description = "A stout barrel, try interacting with it!",
		type = "prop",
		appearance = {
			chars = { "()", "()" },
			color = { WOOD_DARK, WOOD_LIGHT },
			text_color = WOOD_LIGHT,
		},
		loot = {
			count = { min = 1, max = 3 },
			drops = {
				{ item = "bandage", weight = 6 },
				{ item = "plank", weight = 8 },
				{ item = "health_potion", weight = 1 },
			},
		},
		inventory = {
			items = {},
			equipped = { armor = nil, offhand = nil, accessory = nil, mainhand = nil },
			selected_index = nil,
		},
		default_action = "moveable",
		interact_priority = 1,
		tags = {
			moveable = true,
			tilelike = true,
			covers = true,
			attackable = true,
			interactable = true,
			container = true,
		},
		combat = { hit_burst = "dust" },
		stats = {
			health = { base = 4, current = 4 },
			evasion = { base = 0 },
		},
	},
	bookshelf = {
		name = "Bookshelf",
		description = "A bookshelf, try interacting with it!",
		type = "prop",
		appearance = {
			chars = { "[-]", "[-]", "[-]" },
			color = { WOOD_DARK, WOOD, WOOD_LIGHT },
			text_color = WOOD_LIGHT,
		},
		loot = {
			count = { min = 1, max = 3 },
			drops = {
				{ item = "bandage", weight = 6 },
				{ item = "plank", weight = 8 },
				{ item = "health_potion", weight = 1 },
			},
		},
		inventory = {
			items = {},
			equipped = { armor = nil, offhand = nil, accessory = nil, mainhand = nil },
			selected_index = nil,
		},
		interact_priority = 1,
		tags = {
			tilelike = true,
			covers = true,
			attackable = true,
			interactable = true,
			container = true,
		},
		combat = { hit_burst = "dust" },
		stats = {
			health = { base = 4, current = 4 },
			evasion = { base = 0 },
		},
	},

	item = {
		name = "Item",
		description = "An item, try picking it up!",
		type = "prop",
		appearance = {
			chars = { "*" },
			color = { { 0.88, 0.76, 0.34, 1 } },
			text_color = { 0.88, 0.76, 0.34, 1 },
		},
		default_action = "pickupable",
		tags = {
			tilelike = true,
			pickupable = true,
			interactable = true,
			walkable = true,
		},
	},

	phylactery = {
		name = "Phylactery",
		description = "A Phylactery",
		type = "prop",
		natural_height = 0.25,
		appearance = {
			chars = { "<>" },
			color = { { 0.30, 0.06, 0.08, 1 } },
			text_color = { 0.30, 0.06, 0.08, 1 },
		},
		applies_status = { "phylactery_glow", silent = true },
		tags = {
			moveable = false,
			tilelike = true,
			walkable = true,
		},
	},

	--------------------------------------------------------------------------
	-- PROPS: light sources
	--------------------------------------------------------------------------

	campfire = {
		name = "Campfire",
		description = "A Campfire",
		type = "prop",
		natural_height = 0.25,
		appearance = {
			chars = { "%" },
			color = { { 0.92, 0.49, 0.32, 1 } },
			text_color = { 0.92, 0.49, 0.32, 1 },
		},
		emitters = { { particle = "smoke", rate = 1 }, { particle = "ember", rate = 1.2 } },
		light = {
			color = { r = 1.0, g = 0.65, b = 0.25 },
			intensity = 1,
			radius = 11,
			flicker = { amp = 0.02, freq = 2, phase = 3 },
		},
		tags = {
			tilelike = true,
			covers = true,
		},
	},

	crystal = {
		name = "Crystal",
		description = "A Crystal",
		type = "prop",
		appearance = {
			chars = { "<>", "<>" },
			color = { { 0.7, 0.9, 0.95, 1 } },
			text_color = { 0.7, 0.9, 0.95, 1 },
		},
		light = {
			color = { r = 0.7, g = 0.9, b = 1 },
			intensity = 0.7,
			radius = 9,
			flicker = { amp = 0.05, freq = 4, phase = 0 },
		},
		default_action = "moveable",
		tags = {
			moveable = true,
			tilelike = true,
			covers = true,
		},
	},

	street_lamp = {
		name = "Street Lamp",
		description = "A Street Lamp",
		type = "prop",
		appearance = {
			chars = { ".", ".", ".", ".", "#", "#" },
			color = {
				-- wooden post on the shared ramp, then the metal housing
				WOOD_DARK,
				WOOD_DARK,
				WOOD,
				WOOD,
				{ 0.5, 0.5, 0.55, 1 },
				{ 0.5, 0.5, 0.55, 1 },
			},
			text_color = { 0.92, 0.49, 0.32, 1 },
		},
		light = {
			color = { r = 1.0, g = 0.65, b = 0.35 },
			intensity = 0.7,
			radius = 11,
			flicker = { amp = 0.02, freq = 2, phase = 3 },
		},
		tags = {

			moveable = true,
			tilelike = true,
			covers = true,
		},
	},
}
