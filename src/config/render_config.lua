return {
	font = {
		use_pixel = true,
		scale = 3.8,
		base_size = 16,
		ui_scale = 0.875,
		terminal_scale = 0.875,
		medium_scale = 1.1,
		big_scale = 2,
		very_big_scale = 3.5,
		center_nudge_y = 0.075,
	},
	camera = {
		speed = 2,
		draw_margin = 2,
	},
	rendering = {
		default_offset_type = 1,
		offset_amount_factor = 0.4,
		z_size_scale_per_level = 0.055,
		z_offset = 0.125,
		entity_cull_margin = 4,
	},
	lighting = {
		brightness = 0,
		ambient_keys = {
			{ at = 0.00, color = { r = 0.125, g = 0.213, b = 0.422 } }, -- night
			{ at = 0.22, color = { r = 0.125, g = 0.213, b = 0.422 } }, -- night
			{ at = 0.27, color = { r = 1, g = 0.75, b = 0.6 } }, -- dawn
			{ at = 0.33, color = { r = 1, g = 0.85, b = 0.7 } }, -- day
			{ at = 0.70, color = { r = 1, g = 0.85, b = 0.7 } }, --  day
			{ at = 0.78, color = { r = 1, g = 0.75, b = 0.6 } }, -- dusk
			{ at = 0.85, color = { r = 0.125, g = 0.213, b = 0.422 } }, --night
		},
		brightness_keys = {
			{ at = 0.00, v = 1 },
			{ at = 0.26, v = 1 },
			{ at = 0.27, v = 1 },
			{ at = 0.30, v = 1 },
			{ at = 0.70, v = 1 },
			{ at = 0.78, v = 1 },
			{ at = 0.79, v = 1 },
			{ at = 0.85, v = 1 },
		},
		emissive_keys = {
			{ at = 0.00, v = 1.0 },
			{ at = 0.26, v = 1.0 },
			{ at = 0.27, v = 1.0 },
			{ at = 0.30, v = 1 },
			{ at = 0.70, v = 1 },
			{ at = 0.78, v = 1.0 },
			{ at = 0.79, v = 1.0 },
			{ at = 0.85, v = 1.0 },
		},

		dynamic_light_threshold = 0.1,
		light_emissive = 1,
		cover_emissive = 0.5,
		particle_emissive = 0.5,
		entity_emissive = 0.75,
		entity_brightness_boost = 0.4,
		distance_vignette = false,
		distance_drama = 0.5,
		shadow_brightness_scale = 0.25,
		shadow_alpha_scale = 0.7,
		explored_color = { 0.21, 0.271, 0.762, 0.25 },
	},

	vignette = {
		enabled = true,
		strength = 0.8,
		radius = 0.35,
		softness = 0.4,
	},
	debug = {
		show_grid = false,
		grid_color = { 0.5, 0.5, 0.5, 0.3 },
		grid_center_color = { 0.9, 0.3, 0.3, 0.6 },
		grid_center_width = 3,
		sight_color = { 1, 0.85, 0.3, 0.5 },
		bw_mode = 0,
		xray_explored_color = { 0.35, 0.42, 0.9, 0.7 },
		sky_mask_color = { 0.95, 0.45, 0.15, 0.35 },
	},
	particles = {
		count = 400,
		weather_ease_in_duration = 2.0,
		size_scale = 0.5,
		weather_proportion = 0.5,
		burst_height = 0.5,
	},
	animation = {
		tween_slack = 0.02,
		tween_time = 0.5,
		cull_slack = 6,
	},
	combat = {
		glance_damage_color = { 0.6, 0.3, 0.3, 0.5 },
		solid_damage_color = { 0.9, 0.45, 0.2, 0.7 },
		glance_damage_text_color = { 0.6, 0.3, 0.3 },
		solid_damage_text_color = { 0.9, 0.45, 0.2 },
		damage_text_color = { 0.8, 0.1, 0.1 },

		burst_count = 4,
	},
	nearby_range = 5,
}
