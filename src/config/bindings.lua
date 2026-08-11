return {
	{ "attack", "f", category = "combat" },
	{ "aim", "r", category = "combat" },

	{ "interact", "e", category = "interaction" },
	{ "inspect", "t", category = "interaction" },
	{ "grab", "q", category = "interaction" },

	{ "move_up", "up", "w", category = "movement" },
	{ "move_down", "down", "s", category = "movement" },
	{ "move_left", "left", "a", category = "movement" },
	{ "move_right", "right", "d", category = "movement" },
	{ "wait", "space", category = "movement" },
	{ "hold_position", "lctrl", category = "movement" },

	{ "cycle_next", "tab", category = "inventory" },
	{ "use_selected", "u", category = "inventory" },
	{ "place_selected", "p", category = "inventory" },
	{ "select_slot", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", category = "inventory" }, --The order matters since we rely on it in input

	{ "switch_character", "z", category = "hud" },

	{ "reload_prefab", "f1", category = "debug" },
	{ "toggle_profiler", "f2", category = "debug" },
	{ "toggle_perf", "f3", category = "debug" },
	{ "toggle_xray", "f4", category = "debug" },
	{ "toggle_grid", "f5", category = "debug" },
	{ "toggle_bw", "f6", category = "debug" },
	{ "toggle_visualizer", "f7", category = "debug" },
	{ "toggle_font", "f8", category = "debug" },
	{ "switch_offset", "f9", category = "debug" },
	{ "toggle_sky_mask", "f10", category = "debug" },
	{ "debug", "f11", category = "debug" },
	{ "debug_spawn_zombie", "f12", category = "debug" },

	{ "menu_interact", "return", "kpenter", category = "menu" },
	{ "pause", "escape", category = "menu" },
}
