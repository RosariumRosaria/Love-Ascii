local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local entities = require("entities.entities")
local render_utils = require("visuals.render_utils")
local map = require("map.map")
local render_primitives = require("visuals.render_primitives")

local render_handler = {}
local config = require("config")
local tileSize
local smallTileSize
local defaultFont
local smallFont

local MAX_HEIGHT = 5 --TODO whys is this here. Fine for now.
local OFFSET_TYPE = 1
local OFFSET_AMOUNT

function render_handler:switch_offset()
	OFFSET_TYPE = (OFFSET_TYPE % 3) + 1
end

function render_handler:draw_visual(visual, center_x, center_y, visible)
	if visible or not visual.params.needsToBeSeen then
		local x_screem, y_screen = render_utils.get_screen_coords(visual.x, visual.y, center_x, center_y)

		local color = { 1, 1, 1, 1 }

		if visual.rects then
			for _, rect in ipairs(visual.rects) do
				if visual.params.decayOverTime then
					color = render_utils.scale_color(rect.colors[1], visual.params.lifespan / visual.params.initialSpan)
				else
					color = rect.colors[visual.params.i]
				end
				local visualSize = rect.sizes[visual.params.i] * tileSize
				render_primitives.draw_rect(
					x_screem + ((tileSize - visualSize) / 2),
					y_screen + ((tileSize - visualSize) / 2),
					visualSize,
					visualSize,
					color,
					rect.outlineWidth,
					rect.outlineColor,
					rect.roundedAmount
				)
			end
		end

		if visual.panels then
			for _, panel in ipairs(visual.panels) do
				if panel.colors[visual.params.i] then
					color = panel.colors[visual.params.i]
				end

				x_screem, y_screen = render_utils.get_screen_coords(
					(visual.anchor.x + (1 / 3)) or visual.x,
					visual.anchor.y - panel.offsetY or visual.y,
					center_x,
					center_y
				)
				render_primitives.draw_panel(
					x_screem,
					y_screen,
					render_utils.getMaxTextWidth(panel.texts, defaultFont),
					tileSize,
					color,
					panel.outlineWidth or 1,
					panel.outlinecolor[1],
					panel.texts,
					panel.centerText,
					{ 1, 1, 1, 1 },
					tileSize
				)
			end
		end
	end
end

function render_handler:draw_entity(entity, center_x, center_y, visible, explored)
	local tilelike = entities:get_tag_entity(entity, "tilelike")

	if not visible and not (tilelike and explored) then
		return
	end

	local base_color = entity.color

	if tilelike then
		base_color = render_utils.get_effective_color(base_color, visible, explored)
	end

	local x_screem, y_screen = render_utils.get_screen_coords(entity.x, entity.y, center_x, center_y)
	local base = render_utils.distance_scale(entity.x, entity.y, center_x, center_y)

	for i, char_data in ipairs(entity.chars) do
		local scale = render_utils.height_level_scale(entity.z + i, MAX_HEIGHT, visible, base) + 0.3

		local scaled_color = render_utils.scale_color(base_color, scale)

		local dx, dy = render_utils.get_offset(
			entity.z + i - 1,
			OFFSET_TYPE,
			OFFSET_AMOUNT,
			entity.x,
			entity.y,
			center_x,
			center_y
		)
		render_primitives.draw_char(
			x_screem + dx,
			y_screen + dy,
			char_data,
			scaled_color,
			entity.outlineColor,
			entity.rotation,
			entity.naturalRotation
		)
	end
end

function render_handler:draw_tile(tile_data, x, y, center_x, center_y, visible, explored)
	if not visible and not explored then
		return
	end

	local x_screem, y_screen = render_utils.get_screen_coords(x, y, center_x, center_y)

	local base = render_utils.distance_scale(x, y, center_x, center_y)

	for i, tile in ipairs(tile_data) do
		local char = tile.chars[1]
		local alpha = render_utils.height_level_scale(i, MAX_HEIGHT, visible, base)
		local base_color = render_utils.get_effective_color(tile.color, visible, explored)
		if base_color and (not visible or not entities:get_tag_location(x, y, i, "blocks")) then
			local scaled_color = render_utils.scale_color(base_color, alpha)
			local dx, dy = render_utils.get_offset(i, OFFSET_TYPE, OFFSET_AMOUNT, x, y, center_x, center_y)
			render_primitives.draw_char(x_screem + dx, y_screen + dy, char, scaled_color, tile.outlineColor)
		end
	end
end

function render_handler:draw_ui(ui)
	local max_lines = math.floor(ui.height / smallTileSize)
	local total_lines = #ui.texts

	ui.scroll_offset = math.max(0, math.min(ui.scroll_offset, math.max(0, total_lines - max_lines)))

	local start_line = math.max(1, total_lines - ui.scroll_offset - max_lines + 1)
	local end_line = math.min(total_lines, start_line + max_lines - 1)

	local visible_texts = {}
	for i = start_line, end_line do
		table.insert(visible_texts, ui.texts[i])
	end

	render_primitives.draw_panel(
		ui.x,
		ui.y,
		ui.width,
		ui.height,
		ui.color,
		ui.outlineWidth,
		ui.outlinecolor,
		visible_texts,
		ui.centerText,
		{ 1, 1, 1, 1 },
		smallTileSize
	)
end

function render_handler:draw(center_x, center_y)
	local drawDist = 50 --TODO MAGIC

	--Draw Map
	local endX = math.min(center_x + drawDist, map:get_width())
	local endY = math.min(center_y + drawDist, map:get_height())
	local startX = math.max(center_x - drawDist, 1)
	local startY = math.max(center_y - drawDist, 1)
	local tiles = map:get_tiles()

	--Draw Entities
	for _, entity in ipairs(entities:get_entity_list()) do
		render_handler:draw_entity(
			entity,
			center_x,
			center_y,
			map:is_visible(entity.x, entity.y),
			map:is_explored(entity.x, entity.y)
		)
	end

	for y = startY, endY do
		for x = startX, endX do
			local screenX, screenY = render_utils.get_screen_coords(x, y, center_x, center_y)
			--Temporary for debugging.
			if OFFSET_TYPE == 3 then
				love.graphics.setColor(0.5, 0.5, 0.5, 0.1)
				love.graphics.rectangle("line", screenX, screenY, tileSize, tileSize)
				love.graphics.setColor(1, 1, 1, 1)
			end

			self:draw_tile(tiles[y][x], x, y, center_x, center_y, map:is_visible(x, y), map:is_explored(x, y))
		end
	end

	--Draw Visuals
	for _, visual in ipairs(visuals:get_visual_list()) do
		self:draw_visual(visual, center_x, center_y, map:is_visible(visual.x, visual.y))
	end

	--TODO: Is there a better way to know what font I should be using?
	love.graphics.setFont(smallFont)
	for _, ui in ipairs(ui_handler:get_ui_list()) do
		self:draw_ui(ui)
	end
	love.graphics.setFont(defaultFont)
end

function render_handler:load()
	tileSize = config.tileSize
	smallTileSize = config.smallTileSize
	defaultFont = config.font
	smallFont = config.smallFont

	MAX_HEIGHT = 5
	OFFSET_TYPE = 1
	OFFSET_AMOUNT = 0.25 * tileSize
	render_utils.load()
	render_primitives.load()
end

return render_handler
