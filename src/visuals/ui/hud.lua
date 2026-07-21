local stats = require("src.sim.stats")
local inventory = require("src.sim.inventory")
local container = require("src.engine.interaction.container")
local event_log = require("src.engine.event_log")
local panels = require("src.visuals.ui.panels")

local hud = {}

local character_modes = { "stats", "inventory" }
local character_position = 1
local character_panel
local container_panel

function hud:switch_character()
	character_position = (character_position % #character_modes) + 1
	character_panel.mode = character_modes[character_position]
	self:update_character(character_panel.entity)
end

local vital_anchor = { x = 25, y = 25 }
local vitals_panel_opts = {
	x = vital_anchor.x,
	y = vital_anchor.y,
	font = "small",
	center_text = true,
	auto_size = true,
}

function hud:load()
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

	panels:reload_fonts()

	panels:add_panel("terminal", {
		x = start_x,
		y = buffer,
		width = width,
		height = height,
		color = black,
		outline_width = outline_width,
		outline_color = white,
		font = "very_small",
	})
	character_panel = panels:add_panel("character", {
		x = start_x,
		y = start_y,
		width = width,
		height = screen_height - height - (4 * buffer),
		color = black,
		outline_width = outline_width,
		outline_color = white,
		font = "small",
	})
	container_panel = panels:add_panel("container", {
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
	local vitals_panel = panels:add_panel("vitals", vitals_panel_opts)
	vitals_panel.texts = { "" }
	panels:measure_auto_size(vitals_panel)
end

function hud:log_events()
	for _, ev in ipairs(event_log:drain()) do
		if not ev.silent then
			if ev.type == "damage" then
				panels:add_text_to_panel_by_name("terminal", ev.source .. " hit " .. ev.entity .. " for " .. ev.amount)
			elseif ev.type == "heal" then
				panels:add_text_to_panel_by_name("terminal", ev.source .. " healed " .. ev.entity .. " for " .. ev.amount)
			elseif ev.type == "status_expired" then
				panels:add_text_to_panel_by_name("terminal", ev.status .. " wore off " .. ev.entity)
			elseif ev.type == "status_applied" then
				panels:add_text_to_panel_by_name(
					"terminal",
					ev.source .. " applied " .. ev.status .. " to " .. ev.entity
				)
			elseif ev.type == "entity_died" then
				panels:add_text_to_panel_by_name("terminal", ev.entity .. " was killed by " .. ev.source)
			elseif ev.type == "entity_dragged" then
				panels:add_text_to_panel_by_name(
					"terminal",
					ev.source .. " dragged " .. ev.entity .. " to " .. ev.dest_x .. ", " .. ev.dest_y
				)
			elseif ev.type == "action_failed" then
				panels:add_text_to_panel_by_name("terminal", ev.entity .. ": " .. ev.reason)
			elseif ev.type == "item_equipped" then
				panels:add_text_to_panel_by_name(
					"terminal",
					ev.entity .. " equipped " .. ev.item .. " (" .. ev.slot .. ")"
				)
			elseif ev.type == "item_unequipped" then
				panels:add_text_to_panel_by_name(
					"terminal",
					ev.entity .. " unequipped " .. ev.item .. " (" .. ev.slot .. ")"
				)
			elseif ev.type == "item_used" then
				panels:add_text_to_panel_by_name("terminal", ev.entity .. " used " .. ev.item)
			elseif ev.type == "item_consumed" then
				panels:add_text_to_panel_by_name("terminal", ev.item .. " was consumed")
			elseif ev.type == "entity_picked_up" then
				panels:add_text_to_panel_by_name("terminal", ev.source .. " picked up " .. ev.entity)
			elseif ev.type == "entity_placed" then
				panels:add_text_to_panel_by_name("terminal", ev.source .. " placed " .. ev.entity)
			elseif ev.type == "sound" then
				panels:add_text_to_panel_by_name("terminal", "You heard " .. ev.description)
			elseif ev.type == "debug" then
				panels:add_text_to_panel_by_name("terminal", "[DEBUG] " .. ev.message)
			elseif ev.type == "entity_waited" then
				panels:add_text_to_panel_by_name("terminal", ev.entity .. " waited")
			end
		end
	end
end

function hud:update_vitals(entity)
	local stat_name = "health"
	local max = stats.get(entity, stat_name)
	local current = stats.get_current(entity, stat_name)
	local panel = panels:get_panel("vitals")
	panel.texts = { "Health: " .. current .. " / " .. max }
end

local status_panels = {}
local STATUS_GAP = 25
local status_panel_opts =
	{ x = vital_anchor.x, y = vital_anchor.y, font = "very_small", center_text = true, center_vertical = true }

function hud:update_statuses(entity)
	for _, panel in ipairs(status_panels) do
		panels:remove_panel(panel.name)
	end
	status_panels = {}
	if not entity.statuses then
		return
	end
	local max_width = 0
	for i, status in ipairs(entity.statuses) do
		local label = status.name or status.key or "?"
		local panel = panels:add_panel(label .. i, status_panel_opts)
		local duration_text = status.duration and (" (" .. status.duration .. ")") or ""
		panels:add_text_to_panel_by_name(label .. i, label .. duration_text)
		panels:measure_auto_size(panel)
		max_width = math.max(max_width, panel.width)
		table.insert(status_panels, panel)
	end

	local vitals = panels:get_panel("vitals")
	local y = vital_anchor.y + (vitals and vitals.height or 0) + STATUS_GAP
	for _, panel in ipairs(status_panels) do
		panel.width = max_width
		panel.y = y
		y = y + panel.height + 4 * panel.outline_width
	end
end

function hud:update_character(entity)
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
			panels:add_text_to_panel_by_name("character", i .. " - " .. label .. equipped .. charges .. selected)
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
					panels:add_text_to_panel_by_name("container", i .. " - " .. label .. charges .. selected)
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
				panels:add_text_to_panel_by_name("character", stat_name .. ": " .. current .. " / " .. max)
			else
				panels:add_text_to_panel_by_name("character", stat_name .. ": " .. max)
			end
		end
	end
end

return hud
