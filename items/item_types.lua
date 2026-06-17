return {
	sword = {
		name = "Sword",
		description = "A sharp blade for combat.",
		color = { { 0.8, 0.8, 0.8, 1 } },
		slot = "mainhand",
		chars = { "/" },
		volume = 6,
		modifiers = {
			{ stat = "damage", op = "add", value = 3 },
		},
	},
	bow = {
		name = "Bow",
		description = "A keen bow for combat.",
		color = { { 0.8, 0.8, 0.8, 1 } },
		slot = "mainhand",
		chars = { "D" },
		modifiers = {
			{ stat = "damage", op = "add", value = 3 },
		},
		ranged = true,
		charges = 10,
		volume = 6,
		reach = 8,
		max_charges = 10, --TODO: Some kind of quiver
		range = 15,
	},
	health_potion = {
		name = "Health Potion",
		description = "Restores health when consumed.",
		color = { { 1, 0.5, 0.5, 1 } },
		chars = { "&" },
		on_use = { apply_status = "regen" },
		charges = 3,
		max_charges = 3,
	},
	strength_potion = {
		name = "Strength Potion",
		description = "Improves strength when consumed.",
		color = { { 1, 0.5, 0.5, 1 } },
		chars = { "&" },
		on_use = { apply_status = "strength" },
		charges = 1,
	},
	leather_armor = {
		name = "Leather Armor",
		description = "Provides protection against attacks.",
		color = { { 0.5, 0.5, 0.7, 1 } },
		chars = { "A" },
		slot = "armor",
		modifiers = {
			{ stat = "health", op = "add", value = 5 },
		},
	},
	torch = {
		name = "Torch",
		description = "Provides light in dark areas.",
		color = { { 1, 0.35, 0.1, 1 } },
		chars = { "Y" },
		slot = "offhand",
		light = {
			color = { r = 1.0, g = 0.85, b = 0.55 },
			flicker = { amp = 0.05, freq = 8, phase = 4 },
			intensity = 0.5,
			radius = 6,
		},
	},
}
