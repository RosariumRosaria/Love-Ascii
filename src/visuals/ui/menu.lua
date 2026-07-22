local panels = require("src.visuals.ui.panels")
local config = require("src.config.runtime")
local menu = {}

local pause_position = 1
local pause_options = { "RESUME", "RESTART", "QUIT" }

local start_position = 1
local start_options = { "START", "QUIT" }

local dead_position = 1
local dead_options = { "RESPAWN", "RESTART", "QUIT" }

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

function menu:update_pause_menu(dir)
	pause_position = ((pause_position - 1 + (dir or 0)) % #pause_options) + 1
	panels:get_panel("pause_options").texts = build_texts(pause_options, pause_position)
end

function menu:get_pause_option()
	return pause_options[pause_position]
end

function menu:set_pause_visible(visible)
	local panel = panels:get_panel("pause")
	if panel.visible == visible then
		return
	end
	if visible then
		pause_position = 1
		self:update_pause_menu(0)
	end
	panel.visible = visible
	panels:get_panel("pause_options").visible = visible
end

function menu:set_start_visible(visible)
	local panel = panels:get_panel("start")
	if panel.visible == visible then
		return
	end
	if visible then
		start_position = 1
		self:update_start_menu(0)
	end
	panel.visible = visible
	panels:get_panel("start_options").visible = visible
end

function menu:update_start_menu(dir)
	start_position = ((start_position - 1 + (dir or 0)) % #start_options) + 1
	panels:get_panel("start_options").texts = build_texts(start_options, start_position)
end

function menu:get_start_option()
	return start_options[start_position]
end

function menu:set_dead_visible(visible)
	local panel = panels:get_panel("dead")
	if panel.visible == visible then
		return
	end
	if visible then
		dead_position = 1
		self:update_dead_menu(0)
	end
	panel.visible = visible
	panels:get_panel("dead_options").visible = visible
	panels:get_panel("death_reason").visible = visible
end

function menu:update_dead_menu(dir)
	dead_position = ((dead_position - 1 + (dir or 0)) % #dead_options) + 1
	panels:get_panel("dead_options").texts = build_texts(dead_options, dead_position)
end

function menu:get_dead_option()
	return dead_options[dead_position]
end

function menu:load()
	local screen_width = love.graphics.getWidth()
	local outline_width = screen_width / 400
	local black = { 0, 0, 0, 0.5 }
	local white = { 1, 1, 1, 0.5 }
	local paused_panel = panels:add_panel("pause", {
		color = black,
		outline_width = outline_width,
		outline_color = white,
		center_text = true,
		center_vertical = true,
		auto_size = true,
		font = "very_big",
		screen_anchor = { x = "center", y = "center" },
	})
	paused_panel.texts = { "PAUSED" }
	paused_panel.visible = false

	local paused_options_panel = panels:add_panel("pause_options", {
		color = black,
		outline_width = outline_width,
		outline_color = white,
		center_text = true,
		center_vertical = true,
		auto_size = true,
		font = "big",
		screen_anchor = { x = "center", y = "center", margin_y = config.very_big_tile_size * 3 },
	})
	self:update_pause_menu(0)

	paused_options_panel.visible = false

	local start_panel = panels:add_panel("start", {
		color = black,
		outline_width = outline_width,
		outline_color = white,
		center_text = true,
		center_vertical = true,
		auto_size = true,
		font = "very_big",
		screen_anchor = { x = "center", y = "center" },
	})
	start_panel.texts = { "START" }
	start_panel.visible = true

	local start_options_panel = panels:add_panel("start_options", {
		color = black,
		outline_width = outline_width,
		outline_color = white,
		center_text = true,
		center_vertical = true,
		auto_size = true,
		font = "big",
		screen_anchor = { x = "center", y = "center", margin_y = config.very_big_tile_size * 3 },
	})
	self:update_start_menu(0)
	start_options_panel.visible = true

	local dead_panel = panels:add_panel("dead", {
		color = black,
		outline_width = outline_width,
		outline_color = white,
		center_text = true,
		center_vertical = true,
		auto_size = true,
		font = "very_big",
		screen_anchor = { x = "center", y = "center" },
	})
	dead_panel.texts = { "DEAD" }
	dead_panel.visible = false

	local death_reason_panel = panels:add_panel("death_reason", {
		color = black,
		outline_width = outline_width,
		outline_color = white,
		center_text = true,
		center_vertical = true,
		auto_size = true,
		screen_anchor = { x = "center", y = "center", margin_y = config.very_big_tile_size * 1.5 },
	})
	death_reason_panel.texts = { "" }
	death_reason_panel.visible = false
	local dead_options_panel = panels:add_panel("dead_options", {
		color = black,
		outline_width = outline_width,
		outline_color = white,
		center_text = true,
		center_vertical = true,
		auto_size = true,
		font = "big",
		screen_anchor = { x = "center", y = "center", margin_y = config.very_big_tile_size * 4.5 },
	})
	self:update_dead_menu(0)
	dead_options_panel.visible = false
end

return menu
