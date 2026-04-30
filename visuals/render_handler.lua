local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local entities = require("entities.entities")
local render_utils = require("visuals.render_utils")
local map = require("map.map")
local render_primitives = require("visuals.render_primitives")
local config = require("config")
local render_cfg = require("config.render_config")

local render_handler = {}

local tile_size
local small_tile_size
local default_font
local small_font

local max_height = render_cfg.max_height
local offset_type = render_cfg.default_offset_type
local offset_amount
local show_grid = render_cfg.show_grid
local bw_mode = render_cfg.bw_mode
local camera_x = nil
local camera_y = nil
local speed = render_cfg.camera_speed

function render_handler:switch_offset()
	offset_type = (offset_type % 3) + 1
end

function render_handler:toggle_grid()
	show_grid = not show_grid
end

function render_handler:toggle_bw()
	bw_mode = not bw_mode
end

function render_handler:draw_visual(visual, center_x, center_y, visible)
	if visible or not visual.params.needs_to_be_seen then
		local x_screen, y_screen = render_utils.get_screen_coords(visual.x, visual.y, center_x, center_y)

		local color = { 1, 1, 1, 1 }

		if visual.rects then
			for _, rect in ipairs(visual.rects) do
				if visual.params.decay_over_time then
					color = render_utils.scale_color(
						rect.colors[1],
						visual.params.lifespan / visual.params.initial_lifespan
					)
				else
					color = rect.colors[visual.params.i]
				end
				local visual_size = rect.sizes[visual.params.i] * tile_size
				render_primitives.draw_rect(
					x_screen + ((tile_size - visual_size) / 2),
					y_screen + ((tile_size - visual_size) / 2),
					visual_size,
					visual_size,
					color,
					rect.outline_width,
					rect.outline_color,
					rect.rounded_amount
				)
			end
		end

		if visual.panels then
			for _, panel in ipairs(visual.panels) do
				if panel.colors[visual.params.i] then
					color = panel.colors[visual.params.i]
				end

				x_screen, y_screen = render_utils.get_screen_coords(
					(visual.anchor.x + (1 / 3)) or visual.x,
					visual.anchor.y - panel.offset_y or visual.y,
					center_x,
					center_y
				)
				render_primitives.draw_panel(
					x_screen,
					y_screen,
					render_utils.get_max_text_width(panel.texts, default_font),
					tile_size,
					color,
					panel.outline_width or 1,
					panel.outline_color[1],
					panel.texts,
					panel.center_text,
					{ 1, 1, 1, 1 },
					tile_size
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

	local x_screen, y_screen = render_utils.get_screen_coords(entity.x, entity.y, center_x, center_y)
	local base = render_utils.distance_scale(entity.x, entity.y, center_x, center_y)

	if entities:get_tag_entity(entity, "blocks") then
		render_primitives.draw_rect(x_screen, y_screen, tile_size, tile_size, { 0, 0, 0, 1 })
	end

	for i, char_data in ipairs(entity.chars) do
		local scale = render_utils.height_level_scale(entity.z + i, max_height, visible, base) + 0.3

		local scaled_color = render_utils.scale_color(base_color, scale)

		local dx, dy = render_utils.get_offset(
			entity.z + i - 1,
			offset_type,
			offset_amount,
			entity.x,
			entity.y,
			center_x,
			center_y
		)
		local size_scale = 1 + (entity.z + i - 1) * 0.03
		render_primitives.draw_char(
			x_screen + dx,
			y_screen + dy,
			char_data,
			scaled_color,
			entity.outline_color,
			entity.rotation,
			entity.natural_rotation,
			size_scale
		)
	end
end

function render_handler:draw_tile(tile_data, x, y, center_x, center_y, visible, explored, z_from, z_to)
	if not visible and not explored then
		return
	end

	local x_screen, y_screen = render_utils.get_screen_coords(x, y, center_x, center_y)

	local base = render_utils.distance_scale(x, y, center_x, center_y)

	for z = z_from, z_to do
		local tile = tile_data[z]
		if tile then
			local char = tile.chars[1]
			local alpha = render_utils.height_level_scale(z, max_height, visible, base)
			local base_color = render_utils.get_effective_color(tile.color, visible, explored)
			if base_color and (not visible or not entities:get_tag_location(x, y, z, "blocks")) then
				local scaled_color = render_utils.scale_color(base_color, alpha)
				local outline_color = tile.outline_color
				if bw_mode then
					scaled_color = render_utils.to_grayscale(scaled_color)
					if outline_color then
						outline_color = render_utils.to_grayscale(outline_color)
					end
				end
				local dx, dy = render_utils.get_offset(z, offset_type, offset_amount, x, y, center_x, center_y)
				if tile.covers then
					render_primitives.draw_rect(x_screen + dx, y_screen + dy, tile_size, tile_size, { 0, 0, 0, 1 })
				end
				local size_scale = 1 + (z - 1) * 0.03
				render_primitives.draw_char(
					x_screen + dx,
					y_screen + dy,
					char,
					scaled_color,
					outline_color,
					nil,
					nil,
					size_scale
				)
			end
		end
	end
end
function render_handler:draw_ui(ui)
	local max_lines = math.floor(ui.height / small_tile_size)
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
		ui.outline_width,
		ui.outline_color,
		visible_texts,
		ui.center_text,
		{ 1, 1, 1, 1 },
		small_tile_size
	)
end

function render_handler:draw()
	local draw_dist = render_cfg.draw_distance

	--Draw Map
	local cx = math.floor(camera_x or 0)
	local cy = math.floor(camera_y or 0)
	local end_x = math.min(cx + draw_dist, map:get_max_x())
	local end_y = math.min(cy + draw_dist, map:get_max_y())
	local start_x = math.max(cx - draw_dist, 1)
	local start_y = math.max(cy - draw_dist, 1)
	local tiles = map:get_tiles()
	-- Pass 1: underground
	for y = start_y, end_y do
		for x = start_x, end_x do
			self:draw_tile(
				tiles[y][x],
				x,
				y,
				camera_x,
				camera_y,
				map:is_visible(x, y),
				map:is_explored(x, y),
				map.min_z,
				0
			)
		end
	end

	-- Pass 2: ground
	for y = start_y, end_y do
		for x = start_x, end_x do
			self:draw_tile(tiles[y][x], x, y, camera_x, camera_y, map:is_visible(x, y), map:is_explored(x, y), 1, 1)
		end
	end

	--Draw Entities
	for _, entity in ipairs(entities:get_entity_list()) do
		render_handler:draw_entity(
			entity,
			camera_x,
			camera_y,
			map:is_visible(entity.x, entity.y),
			map:is_explored(entity.x, entity.y)
		)
	end

	-- Pass 3: above ground
	for y = start_y, end_y do
		for x = start_x, end_x do
			local screen_x, screen_y = render_utils.get_screen_coords(x, y, camera_x, camera_y)
			if show_grid then
				love.graphics.setColor(0.5, 0.5, 0.5, 0.1)
				love.graphics.rectangle("line", screen_x, screen_y, tile_size, tile_size)
				love.graphics.setColor(1, 1, 1, 1)
			end
			self:draw_tile(
				tiles[y][x],
				x,
				y,
				camera_x,
				camera_y,
				map:is_visible(x, y),
				map:is_explored(x, y),
				2,
				map.max_z
			)
		end
	end

	--Draw Visuals
	for _, visual in ipairs(visuals:get_visual_list()) do
		self:draw_visual(visual, camera_x, camera_y, map:is_visible(visual.x, visual.y))
	end

	--TODO: Is there a better way to know what font I should be using?
	love.graphics.setFont(small_font)
	for _, ui in ipairs(ui_handler:get_ui_list()) do
		self:draw_ui(ui)
	end
	love.graphics.setFont(default_font)
end

function render_handler:load(player_x, player_y)
	camera_x = player_x
	camera_y = player_y
	tile_size = config.tile_size
	small_tile_size = config.small_tile_size
	default_font = config.font
	small_font = config.small_font

	max_height = render_cfg.max_height
	offset_type = render_cfg.default_offset_type
	offset_amount = 0.25 * tile_size
	render_utils.load()
	render_primitives.load()
end

function render_handler:update(target_x, target_y, dt)
	camera_x = camera_x + (target_x - camera_x) * speed * dt
	camera_y = camera_y + (target_y - camera_y) * speed * dt
	print(camera_x, camera_y)
end

return render_handler
