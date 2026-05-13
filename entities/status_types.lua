local entities = require("entities.entities")

return {
	poison = {
		name = "Poison",
		description = "Losing health over time.",
		color = { 0.5, 1, 0.5 },
		duration = 5,
		on_tick = function(entity)
			entities:damage_entity(entity, {
				name = "Poison",
				stats = { damage = { base = 1 } },
			})
		end,
	},
	regen = {
		name = "Regeneration",
		description = "Gaining health over time.",
		color = { 1, 0.5, 0.5 },
		duration = 5,
		on_tick = function(entity)
			entities:heal_entity(entity, {
				name = "Regeneration",
				stats = { heal = { base = 1 } },
			})
		end,
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
		disables_action = true,
		color = { 0.5, 0.5, 1 },
		duration = 2,
	},
	obscured = {
		name = "Obscured",
		description = "Reduced sight range.",
		color = { 0.5, 1, 0.5 },
		duration = 1,
		modifiers = {
			{ stat = "sight", op = "mul", value = 0.5 },
		},
		visual = { alpha = 0.5 },
	},
}
