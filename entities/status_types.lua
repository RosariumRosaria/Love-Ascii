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
}
