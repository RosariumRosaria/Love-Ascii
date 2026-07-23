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
			{ label = "GAMMA", kind = "number" },
			{ label = "FULLSCREEN", kind = "enum" },
			{ label = "FONT", kind = "enum" },
			{ label = "COLOR", kind = "enum" },
			{ label = "SCALE", kind = "number" },
		},
		position = 1,
		panels = { main = "settings", options = "settings_options" },
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

local function build_texts(options, position)
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
		table.insert(texts, "  " .. label .. settings_value .. (i == position and " <" or "  "))
	end
	return texts
end

function menu:refresh(name)
	local options = menus[name].options
	local menu_panels = menus[name].panels
	panels:get_panel(menu_panels.options).texts = build_texts(options, menus[name].position)
	layout_menu(name)
end

function menu:navigate(name, dir)
	local position = menus[name].position
	local options = menus[name].options
	menus[name].position = ((position - 1 + (dir or 0)) % #options) + 1
	menu:refresh(name)
end
function menu:get_option(name)
	return menus[name].options[menus[name].position]
end

function menu:set_death_reason(text)
	panels:get_panel("death_reason").texts = { text }
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
	paused_panel.texts = { "PAUSED" }
	paused_panel.visible = false

	local paused_options_panel = add_menu_panel("pause_options", "big")
	self:refresh("pause")
	paused_options_panel.visible = false

	local start_panel = add_menu_panel("start", "very_big")
	start_panel.texts = { "START" }
	start_panel.visible = false

	local start_options_panel = add_menu_panel("start_options", "big")
	self:refresh("start")
	start_options_panel.visible = false

	local dead_panel = add_menu_panel("dead", "very_big")
	dead_panel.texts = { "DEAD" }
	dead_panel.visible = false

	local death_reason_panel = add_menu_panel("death_reason", nil)
	death_reason_panel.texts = { "" }
	death_reason_panel.visible = false

	local dead_options_panel = add_menu_panel("dead_options", "big")
	self:refresh("dead")
	dead_options_panel.visible = false

	local settings_panel = add_menu_panel("settings", "very_big")
	settings_panel.texts = { "SETTINGS" }
	settings_panel.visible = false

	local settings_options_panel = add_menu_panel("settings_options", "big")
	self:refresh("settings")
	settings_options_panel.visible = false
end

return menu
