local panels = require("src.visuals.ui.panels")
local config = require("src.config.runtime")
local menu = {}

local menus = {
	pause = {
		options = { "RESUME", "RESTART", "QUIT" },
		position = 1,
		panels = { main = "pause", options = "pause_options" },
	},
	start = { options = { "START", "QUIT" }, position = 1, panels = { main = "start", options = "start_options" } },
	dead = {
		options = { "RESPAWN", "RESTART", "QUIT" },
		position = 1,
		panels = { main = "dead", options = "dead_options", extra = "death_reason" },
	},
}

local function build_texts(options, position)
	local texts = {}
	for i, label in ipairs(options) do
		if i > 1 then
			table.insert(texts, " ")
		end
		table.insert(texts, "  " .. label .. (i == position and " <" or "  "))
	end
	return texts
end

function menu:navigate(name, dir)
	local position = menus[name].position
	local options = menus[name].options
	local menu_panels = menus[name].panels
	menus[name].position = ((position - 1 + (dir or 0)) % #options) + 1
	panels:get_panel(menu_panels.options).texts = build_texts(options, menus[name].position)
end
function menu:get_option(name)
	return menus[name].options[menus[name].position]
end

function menu:set_death_reason(text)
	panels:get_panel("death_reason").texts = { text }
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
		self:navigate(name, 0)
	end

	for _, menu_name in pairs(menu_panels) do
		panels:get_panel(menu_name).visible = visible
	end
end

local function add_menu_panel(name, font, offset)
	return panels:add_panel(name, {
		color = { 0, 0, 0, 0.5 },
		outline_width = love.graphics.getWidth() / 400,
		outline_color = { 1, 1, 1, 0.5 },
		center_text = true,
		center_vertical = true,
		auto_size = true,
		font = font,
		screen_anchor = {
			x = "center",
			y = "center",
			margin_y = offset and config.very_big_tile_size * offset or nil,
		},
	})
end

function menu:load()
	local paused_panel = add_menu_panel("pause", "very_big")
	paused_panel.texts = { "PAUSED" }
	paused_panel.visible = false

	local paused_options_panel = add_menu_panel("pause_options", "big", 3)
	self:navigate("pause", 0)
	paused_options_panel.visible = false

	local start_panel = add_menu_panel("start", "very_big")
	start_panel.texts = { "START" }
	start_panel.visible = true

	local start_options_panel = add_menu_panel("start_options", "big", 3)
	self:navigate("start", 0)
	start_options_panel.visible = true

	local dead_panel = add_menu_panel("dead", "very_big")
	dead_panel.texts = { "DEAD" }
	dead_panel.visible = false

	local death_reason_panel = add_menu_panel("death_reason", nil, 1.5)
	death_reason_panel.texts = { "" }
	death_reason_panel.visible = false

	local dead_options_panel = add_menu_panel("dead_options", "big", 4.5)
	self:navigate("dead", 0)
	dead_options_panel.visible = false
end

return menu
