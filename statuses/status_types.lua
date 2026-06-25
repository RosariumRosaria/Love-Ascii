return {
	poison = {
		name = "Poison",
		description = "Losing health over time.",
		color = { 0.5, 1, 0.5 },
		duration = 5,
		on_tick = { damage = 1 },
	},
	regen = {
		name = "Regeneration",
		description = "Gaining health over time.",
		color = { 1, 0.5, 0.5 },
		duration = 5,
		on_tick = { heal = 1 },
		visual = { tint = { 0.5, 1, 0.5 } },
	},
	strength = {
		name = "Strength",
		description = "Increased damage.",
		color = { 0.75, 0.75, 0.5 },
		duration = 5,
		modifiers = {
			{ stat = "damage", op = "add", value = 1 },
		},
	},
	stun = {
		name = "Stun",
		description = "Unable to move or act.",
		tags = { disables_action = true },
		color = { 0.5, 0.5, 1 },
		duration = 2,
	},
	obscured = {
		name = "Obscured",
		description = "Reduced sight range and increased stealth.",
		color = { 0.5, 1, 0.5 },
		duration = 1,
		modifiers = {
			{ stat = "sight", op = "mul", value = 0.5 },
			{ stat = "stealth", op = "mul", value = 2 },
		},
		visual = { alpha = 0.5 },
	},
	barricaded = {
		name = "Barricaded",
		description = "Blocked interaction and increased health.",
		color = { 1, 0.8, 0.5 },
		hp = 5,
		tags = { absorbs = true, disables_interaction = true, remove_when_empty = true },
		visual = { tint = { 1, 0.8, 0.5 } },
	},
}
