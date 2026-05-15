local config = require("config.runtime")
local stats = require("entities.stats")
local inventory = require("entities.inventory")
local event_log = require("engine.event_log")
local small_tile_size
local small_font

local ui_handler = {
	ui_list = {},
}

local status_types = { "stats", "inventory", "statuses" }
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
	status_position = (status_position % #status_types) + 1
	status_panel.mode = status_types[status_position]
	self:update_status(status_panel.entity)
end

function ui_handler:get_ui_list()
	return self.ui_list
end

function ui_handler:get_visible_texts(ui)
	local wrapped = {}
	for _, text in ipairs(ui.texts) do
		local _, lines = small_font:getWrap(text, ui.width)
		if #lines == 0 then
			table.insert(wrapped, "")
		else
			for _, line in ipairs(lines) do
				table.insert(wrapped, line)
			end
		end
	end

	local max_lines = math.floor(ui.height / small_tile_size)
	local total_lines = #wrapped

	ui.scroll_offset = math.max(0, math.min(ui.scroll_offset, math.max(0, total_lines - max_lines)))

	local start_line = math.max(1, total_lines - ui.scroll_offset - max_lines + 1)
	local end_line = math.min(total_lines, start_line + max_lines - 1)

	local visible_texts = {}
	for i = start_line, end_line do
		table.insert(visible_texts, wrapped[i])
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
	small_font = config.small_font
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

function ui_handler:log_events()
	for _, ev in ipairs(event_log:drain()) do
		if ev.type == "damage" then
			self:add_text_to_ui_by_name("terminal", ev.source .. " hit " .. ev.entity .. " for " .. ev.amount)
		elseif ev.type == "heal" then
			self:add_text_to_ui_by_name("terminal", ev.source .. " healed " .. ev.entity .. " for " .. ev.amount)
		elseif ev.type == "status_expired" then
			self:add_text_to_ui_by_name("terminal", ev.status .. " wore off " .. ev.entity)
		elseif ev.type == "status_applied" then
			self:add_text_to_ui_by_name("terminal", ev.source .. " applied " .. ev.status .. " to " .. ev.entity)
		elseif ev.type == "entity_died" then
			self:add_text_to_ui_by_name("terminal", ev.entity .. " was killed by " .. ev.source)
		elseif ev.type == "entity_dragged" then
			self:add_text_to_ui_by_name(
				"terminal",
				ev.source .. " dragged " .. ev.entity .. " to " .. ev.dest_x .. ", " .. ev.dest_y
			)
		elseif ev.type == "action_failed" then
			self:add_text_to_ui_by_name("terminal", ev.entity .. ": " .. ev.reason)
		elseif ev.type == "item_equipped" then
			self:add_text_to_ui_by_name("terminal", ev.entity .. " equipped " .. ev.item .. " (" .. ev.slot .. ")")
		elseif ev.type == "item_unequipped" then
			self:add_text_to_ui_by_name("terminal", ev.entity .. " unequipped " .. ev.item .. " (" .. ev.slot .. ")")
		elseif ev.type == "item_used" then
			self:add_text_to_ui_by_name("terminal", ev.entity .. " used " .. ev.item)
		elseif ev.type == "item_consumed" then
			self:add_text_to_ui_by_name("terminal", ev.item .. " was consumed")
		elseif ev.type == "entity_picked_up" then
			self:add_text_to_ui_by_name("terminal", ev.source .. " picked up " .. ev.entity)
		elseif ev.type == "entity_placed" then
			self:add_text_to_ui_by_name("terminal", ev.source .. " placed " .. ev.entity)
		elseif ev.type == "debug" then
			self:add_text_to_ui_by_name("terminal", "[DEBUG] " .. ev.message)
		end
	end
end

function ui_handler:update_status(entity)
	status_panel.texts = {}
	status_panel.entity = entity
	if status_panel.mode == "stats" and entity.stats then
		for stat_name, stat in pairs(entity.stats) do
			local max = stats.get_stat(entity, stat_name)
			if stat.current ~= nil then
				local current = stats.get_current(entity, stat_name)
				self:add_text_to_ui_by_name("status", stat_name .. ": " .. current .. " / " .. max)
			else
				self:add_text_to_ui_by_name("status", stat_name .. ": " .. max)
			end
		end
	elseif status_panel.mode == "inventory" and entity.inventory then
		for _, item in ipairs(entity.inventory.items) do
			local label = item.name or item.key or "?"

			local equipped = inventory.is_equipped(entity, item) and " (equipped)" or ""
			local selected = inventory.get_selected(entity) and inventory.get_selected(entity) == item and " <" or ""
			self:add_text_to_ui_by_name("status", "- " .. label .. equipped .. selected)
		end
	elseif status_panel.mode == "statuses" and entity.statuses then
		for _, status in ipairs(entity.statuses) do
			local label = status.name or status.key or "?"
			self:add_text_to_ui_by_name("status", "- " .. label .. " (" .. status.duration .. ")")
		end

		if not entity.statuses or #entity.statuses == 0 then
			self:add_text_to_ui_by_name("status", "No statuses")
		end
	end
end

return ui_handler
