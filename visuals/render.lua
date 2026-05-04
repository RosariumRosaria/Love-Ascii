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
local debug_font

local max_height = render_cfg.max_height
local offset_type = render_cfg.default_offset_type
local offset_amount
local show_grid = render_cfg.show_grid
local bw_mode = render_cfg.bw_mode
local show_brightness_debug = render_cfg.show_brightness_debug
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

function render_handler:toggle_brightness_debug()
	show_brightness_debug = not show_brightness_debug
end

function render_handler:draw_visual(visual, center_x, center_y, visible)
	if visible or not visual.params.needs_to_be_seen then
		local x_screen, y_screen = render_utils.get_screen_coords(visual.x, visual.y, center_x, center_y)

		if visual.rects then
			local color = { 1, 1, 1, 1 }
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
				local color = { 1, 1, 1, 1 }
				if panel.colors[visual.params.i] then
					color = panel.colors[visual.params.i]
				end

				x_screen, y_screen = render_utils.get_screen_coords(
					(visual.anchor and visual.anchor.x) or visual.x,
					(visual.anchor and visual.anchor.y - panel.offset_y) or visual.y,
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
					panel.outline_color,
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
		local scale = render_utils.height_level_scale(entity.z + i, max_height, map.max_z, map.min_z, visible, base)
			+ render_cfg.entity_brightness_boost

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
		local size_scale = 1 + (entity.z + i - 1) * render_cfg.z_size_scale_per_level
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
			local z_eff = z + (tile.natural_height or 0)
			local alpha = render_utils.height_level_scale(z_eff, max_height, map.max_z, map.min_z, visible, base)
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
				local base_dx, base_dy =
					render_utils.get_offset(z, offset_type, offset_amount, x, y, center_x, center_y)
				if tile.covers then
					render_primitives.draw_rect(
						x_screen + base_dx,
						y_screen + base_dy,
						tile_size,
						tile_size,
						{ 0, 0, 0, 1 }
					)
				end
				local dx, dy = base_dx, base_dy
				if tile.natural_height then
					dx, dy = render_utils.get_offset(z_eff, offset_type, offset_amount, x, y, center_x, center_y)
					local shadow_color = render_utils.scale_color(scaled_color, render_cfg.shadow_brightness_scale)
					shadow_color[4] = (scaled_color[4] or 1) * render_cfg.shadow_alpha_scale
					render_primitives.draw_char(
						x_screen + base_dx,
						y_screen + base_dy,
						char,
						shadow_color,
						nil,
						tile.rotation,
						tile.natural_rotation,
						1 + (z - 1) * render_cfg.z_size_scale_per_level
					)
				end
				local size_scale = 1 + (z_eff - 1) * render_cfg.z_size_scale_per_level
				render_primitives.draw_char(
					x_screen + dx,
					y_screen + dy,
					char,
					scaled_color,
					outline_color,
					tile.rotation,
					tile.natural_rotation,
					size_scale
				)
				if show_brightness_debug and tile.name ~= "air" then
					love.graphics.setFont(debug_font)
					love.graphics.setColor(1, 1, 0, 1)
					love.graphics.print(string.format("%.2f", alpha), x_screen + dx, y_screen + dy)
					love.graphics.setFont(default_font)
					love.graphics.setColor(1, 1, 1, 1)
				end
			end
		end
	end
end
function render_handler:draw_ui(ui)
	local visible_texts = ui_handler:get_visible_texts(ui)

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
				render_primitives.draw_grid_cell(screen_x, screen_y)
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

function render_handler:reload_fonts()
	tile_size = config.tile_size
	small_tile_size = config.small_tile_size
	default_font = config.font
	small_font = config.small_font
	debug_font = love.graphics.newFont(render_cfg.font_base_size * render_cfg.debug_font_scale)
	offset_amount = render_cfg.offset_amount_factor * tile_size
	render_utils.load()
	render_primitives.load()
	ui_handler:reload_fonts()
end

function render_handler:load(player_x, player_y)
	camera_x = player_x
	camera_y = player_y
	max_height = render_cfg.max_height
	offset_type = render_cfg.default_offset_type
end

function render_handler:update(target_x, target_y, dt)
	camera_x = camera_x + (target_x - camera_x) * speed * dt
	camera_y = camera_y + (target_y - camera_y) * speed * dt
end

return render_handler
