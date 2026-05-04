local config = require("config")

local small_tile_size

local ui_handler = {
	ui_list = {},
}

local status_types = { "stats", "inventory" }
local status_position = 1
local status_panel

local function add_text_to_ui(ui, text)
	if not ui then
		return false
	end
	table.insert(ui.texts, text)

	if #ui.texts > ui.capacity then
		table.remove(ui.texts, 1)
	end
end

function ui_handler:switch_status()
	status_position = (status_position % 2) + 1
	status_panel.mode = status_types[status_position]
	self:update_status(status_panel.entity)
end

function ui_handler:get_ui_list()
	return self.ui_list
end

function ui_handler:get_visible_texts(ui)
	local max_lines = math.floor(ui.height / small_tile_size)
	local total_lines = #ui.texts

	ui.scroll_offset = math.max(0, math.min(ui.scroll_offset, math.max(0, total_lines - max_lines)))

	local start_line = math.max(1, total_lines - ui.scroll_offset - max_lines + 1)
	local end_line = math.min(total_lines, start_line + max_lines - 1)

	local visible_texts = {}
	for i = start_line, end_line do
		table.insert(visible_texts, ui.texts[i])
	end
	return visible_texts
end

function ui_handler:add_ui(x, y, width, height, name, color, outline_width, outline_color, center_text, tile_grid)
	local ui = {
		x = x,
		y = y,
		height = height,
		width = width,
		name = name,
		color = color,
		outline_width = outline_width,
		outline_color = outline_color,
		texts = {},
		center_text = center_text,
		tile_grid = tile_grid,
		scroll_offset = 0,
		capacity = math.floor(height / small_tile_size) * 10,
	}

	table.insert(self.ui_list, ui)

	return ui
end

function ui_handler:get_ui(name)
	for _, ui in ipairs(self.ui_list) do
		if ui.name == name then
			return ui
		end
	end
end

function ui_handler:add_text_to_ui_by_name(name, text)
	add_text_to_ui(self:get_ui(name), text)
end

function ui_handler:reload_fonts()
	small_tile_size = config.small_tile_size
end

function ui_handler:load()
	local screen_height = love.graphics.getHeight()
	local screen_width = love.graphics.getWidth()
	local outline_width = screen_width / 400
	local buffer = 4 * outline_width
	local width = screen_width / 6
	local start_x = screen_width - width - buffer
	local height = (screen_height * 4 / 6) - buffer
	local start_y = height + (2 * buffer)
	local black = { 0, 0, 0, 0.5 }
	local white = { 1, 1, 1, 0.5 }

	self:reload_fonts()

	self:add_ui(start_x, buffer, width, height, "terminal", black, outline_width, white)
	status_panel = self:add_ui(
		start_x,
		start_y,
		width,
		screen_height - height - (4 * buffer),
		"status",
		black,
		outline_width,
		white
	)
	status_panel.mode = "inventory"
end

function ui_handler:update_status(entity)
	status_panel.texts = {}
	status_panel.entity = entity
	if status_panel.mode == "stats" then
		for stat_name, stat in pairs(entity.stats) do
			if type(stat) == "table" then
				local current = stat[stat_name]
				local max = stat["max_" .. stat_name]
				self:add_text_to_ui_by_name("status", stat_name .. ": " .. current .. " / " .. max)
			else
				self:add_text_to_ui_by_name("status", stat_name .. ": " .. stat)
			end
		end
	elseif status_panel.mode == "inventory" then
		for item_name, _ in pairs(entity.inventory) do
			self:add_text_to_ui_by_name("status", "- " .. item_name)
		end
	end
end

return ui_handler
