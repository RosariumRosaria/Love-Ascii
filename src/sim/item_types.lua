local WOOD_DARK = { 0.50, 0.37, 0.26, 1 }
local WOOD = { 0.60, 0.45, 0.32, 1 }
local WOOD_LIGHT = { 0.70, 0.55, 0.40, 1 }
local LINEN = { 0.86, 0.80, 0.68, 1 }
local LINEN_WORN = { 0.72, 0.64, 0.49, 1 }
local STEEL = { 0.8, 0.8, 0.8, 1 }

return {
	dull_sword = {
		name = "Dull Blade", --TODO: someday this should be the ritual weapon used to kill you
		description = "A dull blade, stained with your blood.",
		color = { { 0.9, 0.8, 0.8, 1 } },
		slot = "mainhand",
		chars = { "/" },
		volume = 7,
		modifiers = {
			{ stat = "damage", op = "add", value = 2, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 1, context = "melee" },
		},
	},
	sword = {
		name = "Sword",
		description = "A sharp blade for combat. Balanced for both offense and defense.",
		color = { STEEL },
		slot = "mainhand",
		chars = { "/" },
		volume = 6,
		modifiers = {
			{ stat = "damage", op = "add", value = 3, context = "melee" },
			{ stat = "evasion", op = "add", value = 1, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 1, context = "melee" },
		},
	},
	axe = {
		name = "Axe",
		description = "A heavy, dull, blade for combat. Inaccurate, but effective.",
		color = { STEEL },
		slot = "mainhand",
		chars = { "P" },
		volume = 9,
		modifiers = {
			{ stat = "damage", op = "add", value = 4, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 3, context = "melee" },
			{ stat = "accuracy", op = "add", value = -1, context = "melee" },
		},
	},
	dagger = {
		name = "Dagger",
		description = "A quick blade for combat. Quiet and keen.",
		color = { STEEL },
		slot = "mainhand",
		chars = { "-" },
		volume = 3,
		applies_on_hit = { { name = "bleeding", chance = 50 } },
		modifiers = {
			{ stat = "damage", op = "add", value = 2, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 1, context = "melee" },
			{ stat = "accuracy", op = "add", value = 1, context = "melee" },
		},
	},
	spear = {
		name = "Spear",
		description = "A sharp spear for combat. Accurate.",
		color = { STEEL },
		slot = "mainhand",
		chars = { "|" },
		volume = 5,
		modifiers = {
			{ stat = "damage", op = "add", value = 3, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 1, context = "melee" },
			{ stat = "accuracy", op = "add", value = 1, context = "melee" },
		},
	},
	bow = {
		name = "Bow",
		description = "A keen bow for combat.",
		color = { WOOD_DARK },
		slot = "mainhand",
		chars = { "D" },
		modifiers = {
			{ stat = "damage", op = "add", value = 2, context = "ranged" },
			{ stat = "damage_spread", op = "add", value = 1, context = "ranged" },
			{ stat = "accuracy", op = "add", value = 1, context = "ranged" },
		},
		ranged = true,
		volume = 6,
		reach = 8,
		tags = { requires_ammo = true },
		range = 15,
	},
	arrow = {
		name = "Arrow",
		description = "Sharp arrows for combat.",
		color = { WOOD },
		chars = { "/" },
		slot = "ammo",
		break_chance = 0.5,
		charges = 1,
		modifiers = {
			{ stat = "damage", op = "add", value = 1, context = "ranged" },
		},
		tags = {
			stacks = true,

			consumable = true,
		},
	},
	plank = {
		name = "Plank",
		description = "Can be used to barricade walls and windows.",
		color = { WOOD_LIGHT },
		on_use = { apply_status = "barricaded", target_tag = "barricadeable", targets = true },
		chars = { "=" },
		charges = 1,
		tags = {
			stacks = true,
			consumable = true,
		},
	},
	bandage = {
		name = "Bandage",
		description = "Can be used to bandage wounds.",
		color = { LINEN },
		on_use = { clear_status = "bandageable", burst = { type = "heal", count = 3 } },
		chars = { "~" },
		charges = 1,
		tags = {
			stacks = true,
			consumable = true,
		},
	},
	splint = {
		name = "Splint",
		description = "Can be used to splint broken bones.",
		color = { { 0.66, 0.58, 0.44, 1 } },
		on_use = { clear_status = "splintable", burst = { type = "heal", count = 3 } },
		chars = { "/" },
		charges = 1,
		tags = {
			consumable = true,
		},
	},
	health_potion = {
		name = "Poultice",
		description = "Restores health when consumed.",
		color = { { 0.76, 0.71, 0.52, 1 } },
		chars = { "&" },
		on_use = { apply_status = "regen" },
		charges = 1,
		tags = {
			stacks = true,
			consumable = true,
		},
	},
	strength_potion = {
		name = "Strength Potion",
		description = "Improves strength when consumed.",
		color = { { 0.55, 0.34, 0.72, 1 } },
		chars = { "&" },
		on_use = { apply_status = "strength" },
		charges = 1,
		tags = {
			consumable = true,
		},
	},
	tunic = {
		name = "Tattered Tunic",
		description = "What you died in.",
		color = { LINEN_WORN },
		chars = { "A" },
		slot = "armor",
		modifiers = {
			{ stat = "health", op = "add", value = 2 },
		},
	},
	leather_armor = {
		name = "Leather Armor",
		description = "Provides protection against attacks.",
		color = { { 0.45, 0.32, 0.22, 1 } },
		chars = { "A" },
		slot = "armor",
		modifiers = {
			{ stat = "health", op = "add", value = 5 },
		},
	},
	chainmail = {
		name = "Chainmail",
		description = "Provides protection against attacks.",
		color = { { 0.55, 0.56, 0.60, 1 } },
		chars = { "A" },
		slot = "armor",
		modifiers = {
			{ stat = "health", op = "add", value = 10 },
		},
	},
	platemail = {
		name = "Platemail",
		description = "Provides protection against attacks.",
		color = { { 0.72, 0.74, 0.78, 1 } },
		chars = { "A" },
		slot = "armor",
		modifiers = {
			{ stat = "health", op = "add", value = 15 },
		},
	},
	torch = {
		name = "Torch",
		description = "Provides light in dark areas.",
		color = { { 0.92, 0.49, 0.32, 1 } },
		chars = { "Y" },
		slot = "offhand",
		light = {
			color = { r = 1.0, g = 0.85, b = 0.55 },
			flicker = { amp = 0.05, freq = 8, phase = 4 },
			intensity = 0.5,
			radius = 6,
		},
	},

	-- Natural weapons:
	fists = {
		name = "Fists",
		description = "Bare hands.",
		slot = "mainhand",
		tags = { natural = true },
		modifiers = {
			{ stat = "damage", op = "add", value = 1, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 1, context = "melee" },
		},
	},
	rotting_hands = {
		name = "Rotting Hands",
		description = "Swollen, graceless hands.",
		slot = "mainhand",
		tags = { natural = true },
		volume = 8,
		sound = "a thump",
		modifiers = {
			{ stat = "damage", op = "add", value = 2, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 1, context = "melee" },
		},
	},
	blighted_claws = {
		name = "Blighted Claws",
		description = "Claws slick with rot.",
		slot = "mainhand",
		tags = { natural = true },
		volume = 8,
		sound = "a thump",
		applies_on_hit = { { name = "poison", chance = 50 } },
		modifiers = {
			{ stat = "damage", op = "add", value = 3, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 1, context = "melee" },
		},
	},
	bone_claws = {
		name = "Bone Claws",
		description = "Bare finger bones, worn to points.",
		slot = "mainhand",
		tags = { natural = true },
		volume = 2,
		sound = "the clatter of bones",
		modifiers = {
			{ stat = "damage", op = "add", value = 1, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 1, context = "melee" },
		},
	},
	fangs = {
		name = "Fangs",
		description = "Long teeth, made for opening throats.",
		slot = "mainhand",
		tags = { natural = true },
		volume = 2,
		sound = "the scratch of claws and fangs",
		applies_on_hit = { { name = "bleeding", chance = 50 } },
		modifiers = {
			{ stat = "damage", op = "add", value = 3, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 1, context = "melee" },
		},
	},
	massive_fists = {
		name = "Massive Fists",
		description = "Fists the size of anvils.",
		slot = "mainhand",
		tags = { natural = true },
		volume = 16,
		reach = 20,
		sound = "a thud",
		applies_on_hit = { { name = "stun", chance = 50 } },
		modifiers = {
			{ stat = "damage", op = "add", value = 5, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 2, context = "melee" },
		},
	},
	burning_maw = {
		name = "Burning Maw",
		description = "A furnace behind rows of teeth.",
		slot = "mainhand",
		tags = { natural = true },
		volume = 16,
		reach = 20,
		sound = "a crash",
		attack_burst = "ember",
		applies_on_hit = { { name = "burning", chance = 50 } },
		modifiers = {
			{ stat = "damage", op = "add", value = 6, context = "melee" },
			{ stat = "damage_spread", op = "add", value = 2, context = "melee" },
		},
	},
}
