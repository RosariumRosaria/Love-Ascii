local panels = require("src.visuals.ui.panels")
local inventory = require("src.sim.inventory")
local grab = require("src.engine.interaction.grab")
local item_text = require("src.visuals.ui.item_text")
local hud = require("src.visuals.ui.hud")
local config = require("src.config.runtime")
local render_config = require("src.config.render_config")
local entities = require("src.sim.entities")
local tooltip = {}

local HOVER_PANELS = { "character", "container" }

local function hovered_panel()
	local mx, my = love.mouse.getPosition()
	for _, name in ipairs(HOVER_PANELS) do
		local panel = panels:get_panel(name)
		if panel and panels:mouse_in(panel, mx, my) then
			return name, panel
		end
	end
end

local function hovered_row(panel)
	local mx, my = love.mouse.getPosition()
	return panels:row_at(panel, mx, my)
end

local prev_item
local hover_time = 0

local function teardown()
	hover_time = 0
	panels:remove_panel("tooltip")
	prev_item = nil
end
function tooltip:update(dt)
	local _, panel = hovered_panel()
	local i = hovered_row(panel)
	local item = panel and i and inventory.get_at_index(panel.entity, i)
	if not grab:is_active() and item then
		if item == prev_item then
			hover_time = hover_time + dt

			if hover_time > render_config.hud.tooltip_delay then
				local width = love.graphics.getWidth() / 7

				local tooltip_panel = panels:get_panel("tooltip")
				if not tooltip_panel then
					tooltip_panel = panels:add_panel("tooltip", {
						x = 0,
						y = 0,
						width = width,
						font = "medium",
						offset_y = 1.5,
						outline_width = hud.outline_width,
						outline_color = { 0.5, 0.5, 0.5, 1 },
						color = { 0, 0, 0, 1 },
						text_offset_x = config.terminal_tile_size * 0.5,
						text_offset_y = config.terminal_tile_size * 0.5,
						auto_height = true,
					})

					for _, line in ipairs(item_text.lines(item, entities.player)) do
						panels:add_text_to_panel_by_name("tooltip", line)
					end
					panels:measure_auto_height(tooltip_panel)

					local tile_size = panel.tile_size
					local mx, my = love.mouse.getPosition()
					local line = panels:line_at(panel, mx, my) or 1
					local screen_width = love.graphics.getWidth()
					local screen_height = love.graphics.getHeight()
					local row_y = panel.screen_y + panel.top + (line - 1) * tile_size

					local gap = hud.buffer

					local x = panel.screen_x - tooltip_panel.width - gap
					if x < 0 then
						x = panel.screen_x + panel.width + gap
					end
					local y = row_y + (tile_size / 2) - (tooltip_panel.height / 2)

					tooltip_panel.x = math.max(0, math.min(x, screen_width - tooltip_panel.width))
					tooltip_panel.y = math.max(0, math.min(y, screen_height - tooltip_panel.height))
				end
			end
		else
			teardown()
		end
		prev_item = item
	else
		teardown()
	end
end

return tooltip
