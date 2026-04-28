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
		},
		rects = {
			{
				colors = { { 0.75, 0.75, 0.75, 0.5 } },
				rounded_amount = 1 / 4,
				sizes = { 1 },
			},
		},
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
				colors = { { 0.5, 0.1, 0.1, 0.3 }, { 0.4, 0.07, 0.07, 0.25 }, { 0.3, 0.04, 0.04, 0.2 } },
				rounded_amount = 1 / 4,
				sizes = { 0.8, 0.6, 0.4 },
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
				outline_color = { { 1, 1, 1, 0.5 } },
				offset_y = 1.5,
				center_text = true,
				sizes = { 2 },
			},
		},
	},
}
