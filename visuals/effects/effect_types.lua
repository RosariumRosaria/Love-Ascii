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
			fade_time = 0,
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
			lifespan = 0.4,
			initial_lifespan = 0.4,
			decay_over_time = false,
			i = 1,
			frames = 3,
		},
		rects = {
			{
				colors = { { 1, 0.1, 0.1, 0.3 }, { 0.8, 0.07, 0.07, 0.25 }, { 0.6, 0.04, 0.04, 0.2 } },
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

	arrow = {
		name = "arrow",
		params = {
			lifespan = 0.4,
			initial_lifespan = 0.4,
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
}
