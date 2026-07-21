local config = require("src.config.runtime")
local stats = require("src.sim.stats")
local inventory = require("src.sim.inventory")
local container = require("src.engine.interaction.container")
local event_log = require("src.engine.event_log")
local render_utils = require("src.visuals.render.utils")
local small_tile_size
local small_font
local very_small_tile_size
local very_small_font

local panels = {
	panel_list = {},
}

local character_modes = { "stats", "inventory" }
local character_position = 1
local character_panel
local container_panel

local FONTS = {}

function panels:add_text_to_panel(panel, text)
	if not panel then
		return false
	end
	table.insert(panel.texts, text)

	if #panel.texts > panel.capacity then
		table.remove(panel.texts, 1)
	end
end

function panels:switch_character()
	character_position = (character_position % #character_modes) + 1
	character_panel.mode = character_modes[character_position]
	self:update_character(character_panel.entity)
end

function panels:get_panel_list()
	return self.panel_list
end

function panels:get_visible_texts(panel)
	local font = panel.font or small_font
	local tile_size = panel.tile_size or small_tile_size
	local wrapped = {}
	for _, text in ipairs(panel.texts) do
		local _, lines = font:getWrap(text, panel.width)
		if #lines == 0 then
			table.insert(wrapped, "")
		else
			for _, line in ipairs(lines) do
				table.insert(wrapped, line)
			end
		end
	end

	local max_lines = math.floor(panel.height / tile_size)
	local total_lines = #wrapped

	panel.scroll_offset = math.max(0, math.min(panel.scroll_offset, math.max(0, total_lines - max_lines)))

	local start_line = math.max(1, total_lines - panel.scroll_offset - max_lines + 1)
	local end_line = math.min(total_lines, start_line + max_lines - 1)

	local visible_texts = {}
	for i = start_line, end_line do
		table.insert(visible_texts, wrapped[i])
	end
	return visible_texts
end

function panels:add_panel(name, opts)
	opts = opts or {}

	local screen_width = love.graphics.getWidth()
	local screen_height = love.graphics.getHeight()

	local font = small_font
	local tile_size = small_tile_size

	if opts.font then
		font = FONTS[opts.font].font
		tile_size = FONTS[opts.font].tile
	end

	local width = opts.width or (screen_width / 6)
	local height = opts.height or (screen_height / 6)

	local panel = {
		x = opts.x or 0,
		y = opts.y or 0,
		height = height,
		width = width,
		name = name,
		color = opts.color or { 0, 0, 0, 0.5 },
		outline_width = opts.outline_width or (screen_width / 800),
		outline_color = opts.outline_color or { 1, 1, 1, 0.5 },
		texts = {},
		center_text = opts.center_text or false,
		tile_grid = opts.tile_grid,
		scroll_offset = 0,
		offset_y = (opts.offset_y or 1.5),
		font = font,
		tile_size = tile_size,
		visible = true,
		auto_size = opts.auto_size or false,
		center_vertical = opts.center_vertical or opts.auto_size or false,
		capacity = math.floor(height / tile_size) * 10,
	}

	table.insert(self.panel_list, panel)

	return panel
end

function panels:get_panel(name)
	for _, panel in ipairs(self.panel_list) do
		if panel.name == name then
			return panel
		end
	end
end
function panels:remove_panel(name)
	for i, panel in ipairs(self.panel_list) do
		if panel.name == name then
			table.remove(self.panel_list, i)
			return
		end
	end
end

function panels:add_text_to_panel_by_name(name, text)
	self:add_text_to_panel(self:get_panel(name), text)
end

function panels:clear_panel_by_name(name)
	local panel = self:get_panel(name)
	if not panel then
		return
	end
	panel.texts = {}
end

function panels:reload_fonts()
	small_tile_size = config.small_tile_size
	small_font = config.small_font
	very_small_tile_size = config.terminal_tile_size
	very_small_font = config.terminal_font
	FONTS = {
		very_small = { font = very_small_font, tile = very_small_tile_size },
		small = { font = small_font, tile = small_tile_size },
	}
end
local vital_anchor = { x = 25, y = 25 }
local vitals_panel_opts = {
	x = vital_anchor.x,
	y = vital_anchor.y,
	font = "small",
	center_text = true,
	auto_size = true,
}

function panels:load()
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

	self:add_panel("terminal", {
		x = start_x,
		y = buffer,
		width = width,
		height = height,
		color = black,
		outline_width = outline_width,
		outline_color = white,
		font = "very_small",
	})
	character_panel = self:add_panel("character", {
		x = start_x,
		y = start_y,
		width = width,
		height = screen_height - height - (4 * buffer),
		color = black,
		outline_width = outline_width,
		outline_color = white,
		font = "small",
	})
	container_panel = self:add_panel("container", {
		x = start_x - width - (2 * buffer),
		y = start_y,
		width = width,
		height = screen_height - height - (4 * buffer),
		color = black,
		outline_width = outline_width,
		outline_color = white,
		font = "small",
	})
	container_panel.visible = false
	character_panel.mode = "inventory"
	local vitals_panel = self:add_panel("vitals", vitals_panel_opts)
	vitals_panel.texts = { "" }
	self:measure_auto_size(vitals_panel)
end

function panels:log_events()
	for _, ev in ipairs(event_log:drain()) do
		if not ev.silent then
			if ev.type == "damage" then
				self:add_text_to_panel_by_name("terminal", ev.source .. " hit " .. ev.entity .. " for " .. ev.amount)
			elseif ev.type == "heal" then
				self:add_text_to_panel_by_name("terminal", ev.source .. " healed " .. ev.entity .. " for " .. ev.amount)
			elseif ev.type == "status_expired" then
				self:add_text_to_panel_by_name("terminal", ev.status .. " wore off " .. ev.entity)
			elseif ev.type == "status_applied" then
				self:add_text_to_panel_by_name("terminal", ev.source .. " applied " .. ev.status .. " to " .. ev.entity)
			elseif ev.type == "entity_died" then
				self:add_text_to_panel_by_name("terminal", ev.entity .. " was killed by " .. ev.source)
			elseif ev.type == "entity_dragged" then
				self:add_text_to_panel_by_name(
					"terminal",
					ev.source .. " dragged " .. ev.entity .. " to " .. ev.dest_x .. ", " .. ev.dest_y
				)
			elseif ev.type == "action_failed" then
				self:add_text_to_panel_by_name("terminal", ev.entity .. ": " .. ev.reason)
			elseif ev.type == "item_equipped" then
				self:add_text_to_panel_by_name(
					"terminal",
					ev.entity .. " equipped " .. ev.item .. " (" .. ev.slot .. ")"
				)
			elseif ev.type == "item_unequipped" then
				self:add_text_to_panel_by_name(
					"terminal",
					ev.entity .. " unequipped " .. ev.item .. " (" .. ev.slot .. ")"
				)
			elseif ev.type == "item_used" then
				self:add_text_to_panel_by_name("terminal", ev.entity .. " used " .. ev.item)
			elseif ev.type == "item_consumed" then
				self:add_text_to_panel_by_name("terminal", ev.item .. " was consumed")
			elseif ev.type == "entity_picked_up" then
				self:add_text_to_panel_by_name("terminal", ev.source .. " picked up " .. ev.entity)
			elseif ev.type == "entity_placed" then
				self:add_text_to_panel_by_name("terminal", ev.source .. " placed " .. ev.entity)
			elseif ev.type == "sound" then
				self:add_text_to_panel_by_name("terminal", "You heard " .. ev.description)
			elseif ev.type == "debug" then
				self:add_text_to_panel_by_name("terminal", "[DEBUG] " .. ev.message)
			elseif ev.type == "entity_waited" then
				self:add_text_to_panel_by_name("terminal", ev.entity .. " waited")
			end
		end
	end
end

function panels:measure_auto_size(panel)
	local line_height = panel.tile_size or small_tile_size
	local outline = panel.outline_width or 1
	local pad_x = outline + line_height * 0.25
	local pad_y = line_height * 0.2
	panel.width = render_utils.get_max_text_width(panel.texts, panel.font) + pad_x * 2
	panel.height = #panel.texts * line_height + pad_y * 2
end

function panels:update_vitals(entity)
	local stat_name = "health"
	local max = stats.get(entity, stat_name)
	local current = stats.get_current(entity, stat_name)
	local panel = self:get_panel("vitals")
	panel.texts = { "Health: " .. current .. " / " .. max }
end

local status_panels = {}
local STATUS_GAP = 25
local status_panel_opts =
	{ x = vital_anchor.x, y = vital_anchor.y, font = "very_small", center_text = true, center_vertical = true }

function panels:update_statuses(entity)
	for _, panel in ipairs(status_panels) do
		self:remove_panel(panel.name)
	end
	status_panels = {}
	if not entity.statuses then
		return
	end
	local max_width = 0
	for i, status in ipairs(entity.statuses) do
		local label = status.name or status.key or "?"
		local panel = self:add_panel(label .. i, status_panel_opts)
		local duration_text = status.duration and (" (" .. status.duration .. ")") or ""
		self:add_text_to_panel_by_name(label .. i, label .. duration_text)
		self:measure_auto_size(panel)
		max_width = math.max(max_width, panel.width)
		table.insert(status_panels, panel)
	end

	local vitals = self:get_panel("vitals")
	local y = vital_anchor.y + (vitals and vitals.height or 0) + STATUS_GAP
	for _, panel in ipairs(status_panels) do
		panel.width = max_width
		panel.y = y
		y = y + panel.height + 4 * panel.outline_width
	end
end

function panels:update_character(entity)
	character_panel.texts = {}
	character_panel.entity = entity

	if (character_panel.mode == "inventory" or container.is_open) and entity.inventory then
		for i, item in ipairs(entity.inventory.items) do
			local label = item.name or item.key or "?"

			local equipped = inventory.is_equipped(entity, item) and " (equipped)" or ""

			local charges = ""
			if item.charges then
				charges = " [" .. item.charges
				if item.max_charges then
					charges = charges .. "/" .. item.max_charges
				end
				charges = charges .. "]"
			end

			local selected = not container.focus_container
					and inventory.get_selected(entity)
					and inventory.get_selected(entity) == item
					and " <"
				or ""
			self:add_text_to_panel_by_name("character", i .. " - " .. label .. equipped .. charges .. selected)
		end
		container_panel.visible = container.is_open
		if container.is_open then
			container_panel.texts = {}
			local container_entity = container:get()
			if container_entity then
				for i, item in ipairs(container_entity.inventory.items) do
					local label = item.name or item.key or "?"

					local charges = ""
					if item.charges then
						charges = " [" .. item.charges
						if item.max_charges then
							charges = charges .. "/" .. item.max_charges
						end
						charges = charges .. "]"
					end

					local selected = container.focus_container
							and inventory.get_selected(container_entity)
							and inventory.get_selected(container_entity) == item
							and " <"
						or ""
					self:add_text_to_panel_by_name("container", i .. " - " .. label .. charges .. selected)
				end
			end
		end
	elseif character_panel.mode == "stats" and entity.stats then
		local weapon = inventory.get_equipped(entity, "mainhand")
		local attack_context = weapon and weapon.ranged and "ranged" or "melee"
		for stat_name, stat in pairs(entity.stats) do
			local max = stats.get(entity, stat_name, attack_context)
			if stat.current ~= nil then
				local current = stats.get_current(entity, stat_name)
				self:add_text_to_panel_by_name("character", stat_name .. ": " .. current .. " / " .. max)
			else
				self:add_text_to_panel_by_name("character", stat_name .. ": " .. max)
			end
		end
	end
end

return panels
