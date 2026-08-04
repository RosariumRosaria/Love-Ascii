local panels = require("src.visuals.ui.panels")
local config = require("src.config.runtime")
local settings = require("src.config.settings")
local menu = {}

local menus = {
	pause = {
		options = {
			{ label = "RESUME", kind = "action" },
			{ label = "SETTINGS", kind = "action" },
			{ label = "RESTART", kind = "action" },
			{ label = "QUIT", kind = "action" },
		},
		position = 1,
		panels = { main = "pause", options = "pause_options" },
	},
	start = {
		options = {
			{ label = "START", kind = "action" },
			{ label = "SETTINGS", kind = "action" },
			{ label = "QUIT", kind = "action" },
		},
		position = 1,
		panels = { main = "start", options = "start_options" },
	},
	dead = {
		options = {
			{ label = "RESPAWN", kind = "action" },
			{ label = "RESTART", kind = "action" },
			{ label = "QUIT", kind = "action" },
		},
		position = 1,
		panels = { main = "dead", options = "dead_options", extra = "death_reason" },
	},
	settings = {
		options = {
			{ label = "BACK", kind = "action" },
			{ label = "RESET", kind = "action" },
			{ label = "KEYBINDS", kind = "action" },
			{ label = "GAMMA", kind = "number" },
			{ label = "FULLSCREEN", kind = "enum" },
			{ label = "FONT", kind = "enum" },
			{ label = "COLOR", kind = "enum" },
			{ label = "SCALE", kind = "number" },
		},
		position = 1,
		panels = { main = "settings", options = "settings_options" },
	},
	keybinds = {
		options = {},
		position = 1,
		panels = { main = "keybinds", options = "keybinds_options" },
	},
}

local LAYOUT_ORDER = { "main", "extra", "options" }
local GAP_LINES = 1

local function layout_menu(name)
	local menu_panels = menus[name].panels
	local gap = config.very_big_tile_size * GAP_LINES

	local stack, total = {}, 0
	for _, key in ipairs(LAYOUT_ORDER) do
		local panel = menu_panels[key] and panels:get_panel(menu_panels[key])
		if panel then
			panels:measure_auto_size(panel)
			total = total + panel.height + (#stack > 0 and gap or 0)
			table.insert(stack, panel)
		end
	end

	local top = 0
	for _, panel in ipairs(stack) do
		panel.screen_anchor.margin_y = top + panel.height / 2 - total / 2
		top = top + panel.height + gap
	end
end

local function build_texts(options, position, slot_position)
	local texts = {}
	for i, option in ipairs(options) do
		if i > 1 then
			table.insert(texts, " ")
		end
		local label = option.label
		local settings_value = ""

		if option.kind == "number" or option.kind == "enum" then
			settings_value = ": " .. tostring(settings:value_text(label)) .. " "
		end

		if option.kind == "keybind" then
			local id = option.id
			local slots = settings:binding_texts(id)
			settings_value = ":"
			if slots then
				for ii, slot in ipairs(slots) do
					settings_value = settings_value
						.. " ["
						.. tostring(slot)
						.. "]"
						.. ((i == position and ii == slot_position) and " <" or "  ")
				end
			end
			table.insert(texts, "  " .. label .. settings_value)
		else
			table.insert(texts, "  " .. label .. settings_value .. (i == position and " <" or "  "))
		end
	end
	return texts
end

function menu:refresh(name)
	local options = menus[name].options
	local menu_panels = menus[name].panels
	panels:set_panel_text_by_name(
		menu_panels.options,
		build_texts(options, menus[name].position, menus[name].slot or 1)
	)
	layout_menu(name)
end

function menu:navigate(name, dir)
	local position = menus[name].position
	local options = menus[name].options
	menus[name].position = ((position - 1 + dir) % #options) + 1
	if options[menus[name].position].kind == "category" then
		self:navigate(name, dir)
	end
	menu:refresh(name)
end

function menu:navigate_slot(name, dir)
	local options = menus[name].options
	if options[menus[name].position].kind ~= "keybind" then
		return nil
	end
	local slot = menus[name].slot or 1
	menus[name].slot = ((slot - 1 + dir) % 2) + 1
	menu:refresh(name)
end

function menu:get_option(name)
	return menus[name].options[menus[name].position]
end

function menu:get_slot(name)
	return menus[name].slot
end

function menu:set_death_reason(text)
	panels:set_panel_text_by_name("death_reason", { text })
	layout_menu("dead")
end

function menu:reset()
	for _, entry in pairs(menus) do
		entry.position = 1
	end
end
function menu:set_visible(name, visible)
	local menu_panels = menus[name].panels
	local panel = panels:get_panel(menu_panels.main)
	if panel.visible == visible then
		return
	end
	if visible then
		menus[name].position = 1
		self:refresh(name)
	end

	for _, menu_name in pairs(menu_panels) do
		panels:get_panel(menu_name).visible = visible
	end
end

local function add_menu_panel(name, font)
	return panels:add_panel(name, {
		color = { 0, 0, 0, 0.5 },
		outline_width = love.graphics.getWidth() / 400,
		outline_color = { 1, 1, 1, 0.5 },
		center_text = true,
		center_vertical = true,
		auto_size = true,
		font = font,

		screen_anchor = { x = "center", y = "center", margin_y = 0 },
	})
end

function menu:load()
	local paused_panel = add_menu_panel("pause", "very_big")
	panels:set_panel_text(paused_panel, { "PAUSED" })
	paused_panel.visible = false

	local paused_options_panel = add_menu_panel("pause_options", "big")
	self:refresh("pause")
	paused_options_panel.visible = false

	local start_panel = add_menu_panel("start", "very_big")
	panels:set_panel_text(start_panel, { "START" })
	start_panel.visible = false

	local start_options_panel = add_menu_panel("start_options", "big")
	self:refresh("start")
	start_options_panel.visible = false

	local dead_panel = add_menu_panel("dead", "very_big")
	panels:set_panel_text(dead_panel, { "DEAD" })
	dead_panel.visible = false

	local death_reason_panel = add_menu_panel("death_reason", nil)
	panels:set_panel_text(death_reason_panel, { "" })
	death_reason_panel.visible = false

	local dead_options_panel = add_menu_panel("dead_options", "big")
	self:refresh("dead")
	dead_options_panel.visible = false

	local settings_panel = add_menu_panel("settings", "very_big")
	panels:set_panel_text(settings_panel, { "SETTINGS" })
	settings_panel.visible = false

	local settings_options_panel = add_menu_panel("settings_options", "big")
	self:refresh("settings")
	settings_options_panel.visible = false

	local keybinds_panel = add_menu_panel("keybinds", "very_big")
	panels:set_panel_text(keybinds_panel, { "KEYBINDS" })
	keybinds_panel.visible = false

	local keybinds_options_panel = add_menu_panel("keybinds_options", "medium")

	local bindings = settings:get_keybinds()
	table.insert(menus["keybinds"].options, { label = "BACK", kind = "action" })
	table.insert(menus["keybinds"].options, { label = "RESET", kind = "action" })
	local category = nil
	for _, binding in ipairs(bindings) do
		if not category or category ~= binding.category then
			category = binding.category
			local label = string.upper(category):gsub("_", " ")
			table.insert(menus["keybinds"].options, { label = label, kind = "category" })
		end
		local label = string.upper(binding[1]):gsub("_", " ")
		table.insert(menus["keybinds"].options, { id = binding[1], label = label, kind = "keybind" })
	end
	self:refresh("keybinds")
	keybinds_options_panel.visible = false
end

return menu
