return {
	trail = {
		name = "trail",
		params = {
			lifespan = 0.4,
			initialSpan = 0.4,
			decayOverTime = true,
			i = 1,
			frames = 1,
			needsToBeSeen = true,
		},
		rects = {
			{
				colors = { { 0.75, 0.75, 0.75, 0.5 } },
				roundedAmount = 1 / 4,
				sizes = { 1 },
			},
		},
	},
	attack = {
		name = "attack",
		params = {
			lifespan = 0.4,
			initialSpan = 0.4,
			decayOverTime = false,
			i = 1,
			frames = 3,
		},
		rects = {
			{
				colors = { { 0.5, 0.1, 0.1, 0.3 }, { 0.4, 0.07, 0.07, 0.25 }, { 0.3, 0.04, 0.04, 0.2 } },
				roundedAmount = 1 / 4,
				sizes = { 0.8, 0.6, 0.4 },
			},
		},
	},
	ping = {
		name = "ping",
		params = {
			lifespan = 1,
			initialSpan = 1,
			decayOverTime = true,
			i = 1,
			frames = 1,
		},
		rects = {
			{
				colors = { { 0.35, 0.75, 0.55, 0.5 } },
				roundedAmount = 1 / 4,
				sizes = { 1 },
			},
		},
	},
	alert = {
		name = "alert",
		params = {
			lifespan = 2,
			initialSpan = 2,
			i = 1,
			frames = 1,
			needsToBeSeen = true,
		},
		panels = {
			{
				texts = { "!" },
				colors = { { 0, 0, 0.0, 0.5 } },
				outlinecolor = { { 1, 1, 1, 0.5 } },
				offsetY = 1.5,
				centerText = true,
				sizes = { 2 },
			},
		},
	},
}
