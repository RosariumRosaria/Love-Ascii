return {
	font = {
		use_pixel = true,
		scale = 3.5,
		base_size = 16,
		ui_scale = 0.875,
		terminal_scale = 0.75,
	},
	camera = {
		speed = 2,
		draw_distance = 23,
	},
	rendering = {
		default_offset_type = 1,
		offset_amount_factor = 0.3,
		z_size_scale_per_level = 0.02,
	},
	lighting = {

		ambient_keys = {
			{ at = 0.00, color = { r = 0.35, g = 0.321, b = 0.41 } }, -- night
			{ at = 0.22, color = { r = 0.35, g = 0.321, b = 0.41 } }, -- night
			{ at = 0.27, color = { r = 1, g = 0.8, b = 0.75 } }, -- dawn
			{ at = 0.33, color = { r = 1, g = 0.95, b = 0.9 } }, -- day
			{ at = 0.70, color = { r = 1, g = 0.95, b = 0.9 } }, --  day
			{ at = 0.78, color = { r = 1, g = 0.8, b = 0.75 } }, -- dusk
			{ at = 0.85, color = { r = 0.35, g = 0.321, b = 0.41 } }, --night
		},

		dynamic_light_threshold = 0.1,
		light_emissive = 0.8,
		cover_emissive = 0.5,
		z_falloff = 0, --todo should maybe be removed instead of set to 0
		entity_brightness_boost = 0.4,
		distance_drama = 0.5,
		brightness = 1,
		shadow_brightness_scale = 0.25,
		shadow_alpha_scale = 0.7,
		explored_color = { 0.861, 0.771, 0.502, 0.2 },
	},
	debug = {
		show_grid = false,
		grid_color = { 0.5, 0.5, 0.5, 0.3 },
		bw_mode = 0,
	},
	particles = {
		count = 400,
		weather_ease_in_duration = 2.0,
		size_scale = 0.5,
		weather_proportion = 0.5,
	},
	animation = {
		tween_slack = 0.02,
		tween_time = 0.5,
	},
}
