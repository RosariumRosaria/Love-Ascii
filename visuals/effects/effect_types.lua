return {
	trail = {
		name = "trail",
		params = {
			lifespan = 0.4,
			initial_lifespan = 0.4,
			decay_over_time = true,
			i = 1,
			frames = 1,
			needs_to_be_seen = true,
			buffered = true,
		},
		rects = {
			{
				colors = { { 0.75, 0.75, 0.75, 0.5 } },
				rounded_amount = 1 / 4,
				sizes = { 1 },
			},
		},
	},
	sound_ring = {
		name = "sound_ring",
		generate = "ring",
		params = {
			expand_time = 0.45,
			duration = 0.45,
			age = 0,
			reach = 4,
			peak_alpha = 0.035,
			alpha_variance = 1,
			color = { 0.8, 0.85, 1.0 },
			decay_over_time = false,
			i = 1,
			width = 1.25,
			frames = 1,
			needs_to_be_seen = false,
		},
		rects = {},
	},
	attack = {
		name = "attack",
		params = {
			lifespan = 0.2,
			initial_lifespan = 0.2,
			decay_over_time = false,
			i = 1,
			frames = 3,
		},
		rects = {
			{
				colors = { { 1, 0.1, 0.1, 0.2 }, { 0.8, 0.07, 0.07, 0.15 }, { 0.6, 0.04, 0.04, 0.1 } },
				rounded_amount = 1 / 4,
				sizes = { 0.8, 0.6, 0.4 },
			},
		},
	},
	reticle = {
		name = "reticle",
		params = {
			lifespan = 0.4,
			initial_lifespan = 0.4,
			decay_over_time = false,
			repeats = true,
			i = 1,
			frames = 2,
		},
		rects = {
			{
				colors = { { 0.7, 0.3, 0.3, 0.6 } },
				rounded_amount = 1 / 4,
				sizes = { 0.8, 0 },
			},
		},
	},
	ping = {
		name = "ping",
		params = {
			lifespan = 1,
			initial_lifespan = 1,
			decay_over_time = true,
			i = 1,
			frames = 1,
		},
		rects = {
			{
				colors = { { 0.35, 0.75, 0.55, 0.5 } },
				rounded_amount = 1 / 4,
				sizes = { 1 },
			},
		},
	},
	alert = {
		name = "alert",
		params = {
			lifespan = 2,
			initial_lifespan = 2,
			i = 1,
			frames = 1,
			needs_to_be_seen = true,
		},
		panels = {
			{
				texts = { "!" },
				colors = { { 0, 0, 0.0, 0.5 } },
				offset_y = 1.25,
			},
		},
	},

	huh = {
		name = "huh",
		params = {
			lifespan = 2,
			initial_lifespan = 2,
			i = 1,
			frames = 1,
			needs_to_be_seen = true,
		},
		panels = {
			{
				texts = { "?" },
				colors = { { 0, 0, 0.0, 0.5 } },
				offset_y = 1.25,
			},
		},
	},
	projectile = {
		name = "projectile",
		generate = "travel",

		params = {
			needs_to_be_seen = false,
			speed = 25,
		},
		glyph = { char = "#->", color = { 0.40, 0.26, 0.116, 1 }, size = 0.33 },
	},

	arrow = {
		name = "arrow",
		params = {
			lifespan = 0.4,
			initial_lifespan = 0.4,
			buffered = true,
			i = 1,
			frames = 1,
			needs_to_be_seen = false,
		},
		panels = {
			{
				texts = { "^" },
				colors = { { 0, 0, 0.0, 0 } },
			},
		},
	},
	ping_goal = {
		name = "ping_goal",
		params = {
			lifespan = 0.4,
			initial_lifespan = 0.4,
			decay_over_time = false,
			i = 1,
			frames = 1,
		},
		rects = {
			{
				colors = { { 0.7, 0.3, 0.3, 0.6 } },
				rounded_amount = 1 / 4,
				sizes = { 0.8 },
			},
		},
	},
	ping_last_known = {
		name = "ping_last_known",
		params = {
			lifespan = 0.4,
			initial_lifespan = 0.4,
			decay_over_time = false,
			i = 1,
			frames = 1,
		},
		rects = {
			{
				colors = { { 0.3, 0.3, 0.7, 0.6 } },
				rounded_amount = 1 / 4,
				sizes = { 0.8 },
			},
		},
	},

	damage_number = {
		name = "damage_number",
		layer = "above_entity",

		generate = "bounce",
		params = {
			duration = 1,
			buffered = true,
			bounce_height = 0.5,
			bounce_times = 2,
			decay_over_time = true, --todo make this apply to glyphs
			needs_to_be_seen = true,
			jitter = true,
		},
		glyph = { char = 0, color = { 0.8, 0.1, 0.1, 0.5 }, size = 0.33 },
	},
}
