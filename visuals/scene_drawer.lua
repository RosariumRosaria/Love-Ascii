local ui_handler = require("visuals.ui")
local entities = require("entities.entities")
local render_utils = require("visuals.render_utils")
local map = require("map.map")
local render_primitives = require("visuals.render_primitives")
local config = require("config.runtime")
local render_cfg = require("config.render_config")
local debug_state = require("debug.debug_state")
local draw_buffer = require("visuals.draw_buffer")

local scene_drawer = {}

local tile_size
local small_tile_size
local default_font
local small_font

local max_height = render_cfg.max_height
local offset_amount

local function apply_bw_mode(color, outline_color)
	if not debug_state.bw_mode then
		return color, outline_color
	end

	local c = render_utils.to_grayscale(color)
	local oc = outline_color and render_utils.to_grayscale(outline_color) or nil
	return c, oc
end

local function get_offset(z, x, y, cx, cy)
	return render_utils.get_offset(z, debug_state.offset_type, offset_amount, x, y, cx, cy)
end

local function emit_char(params)
	draw_buffer:emit({
		z = params.z,
		y = params.y,
		layer = params.layer,
		kind = "char",
		x_screen = params.x_screen,
		y_screen = params.y_screen,
		char = params.char,
		color = params.color,
		outline_color = params.outline_color,
		rotation = params.rotation,
		natural_rotation = params.natural_rotation,
		size_scale = params.size_scale,
	})
end

local function emit_cover_rect(layer, z, y, x_screen, y_screen)
	draw_buffer:emit({
		z = z,
		y = y,
		layer = layer,
		kind = "rect",
		x_screen = x_screen,
		y_screen = y_screen,
		color = { 0, 0, 0, 1 },
		w = tile_size,
		h = tile_size,
	})
end

function scene_drawer:draw_visual(visual, center_x, center_y, visible)
	love.graphics.setFont(default_font)

	if not (visible or not visual.params.needs_to_be_seen) then
		return
	end

	local x_screen, y_screen = render_utils.get_screen_coords(visual.x, visual.y, center_x, center_y)

	-- rects
	if visual.rects then
		local color = { 1, 1, 1, 1 }

		for _, rect in ipairs(visual.rects) do
			if visual.params.decay_over_time then
				color =
					render_utils.scale_color(rect.colors[1], visual.params.lifespan / visual.params.initial_lifespan)
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

	-- panels
	if visual.panels then
		for _, panel in ipairs(visual.panels) do
			local color = panel.colors[visual.params.i] or { 1, 1, 1, 1 }
			local size_scale = (panel.sizes and panel.sizes[visual.params.i]) or 1
			local rect_size = tile_size * size_scale

			local px, py = render_utils.get_screen_coords(
				(visual.anchor and visual.anchor.x) or visual.x,
				(visual.anchor and visual.anchor.y - panel.offset_y) or visual.y,
				center_x,
				center_y
			)

			local pad = (rect_size - tile_size) / 2

			render_primitives.draw_rect(
				px - pad,
				py - pad,
				rect_size,
				rect_size,
				color,
				panel.outline_width or 1,
				panel.outline_color
			)

			for _, text in ipairs(panel.texts) do
				render_primitives.draw_char(px, py, text, { 1, 1, 1, 1 }, nil, 0, 0, size_scale)
			end
		end
	end
end

function scene_drawer:draw_ui(ui)
	love.graphics.setFont(small_font)

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

function scene_drawer:emit_tile_at_z(tile, x, y, z, center_x, center_y, visible, explored)
	if not tile then
		return
	end
	if not visible and not explored then
		return
	end

	local x_screen, y_screen = render_utils.get_screen_coords(x, y, center_x, center_y)

	local base = render_utils.distance_scale(x, y, center_x, center_y)

	local char = tile.chars[1]
	local natural_height = tile.natural_height or 0
	local z_eff = z + natural_height

	local alpha = render_utils.height_level_scale(z_eff, max_height, map.max_z, map.min_z, visible, base)

	local base_color = render_utils.get_effective_color(tile.color, visible, explored)
	local scaled_color = render_utils.scale_color(base_color, alpha)

	local outline_color = tile.outline_color

	scaled_color, outline_color = apply_bw_mode(scaled_color, outline_color)

	local base_dx, base_dy = get_offset(z, x, y, center_x, center_y)

	if tile.covers then
		emit_cover_rect(draw_buffer.LAYER.TILE_COVER, z, y, x_screen + base_dx, y_screen + base_dy)
	end

	local dx, dy = base_dx, base_dy
	local size_scale = 1 + (z_eff - 1) * render_cfg.z_size_scale_per_level

	if tile.natural_height then
		dx, dy = get_offset(z_eff, x, y, center_x, center_y)

		local shadow_color = render_utils.scale_color(scaled_color, render_cfg.shadow_brightness_scale)

		shadow_color[4] = (scaled_color[4] or 1) * render_cfg.shadow_alpha_scale

		emit_char({
			z = z,
			y = y,
			layer = draw_buffer.LAYER.TILE_SHADOW,
			x_screen = x_screen + base_dx,
			y_screen = y_screen + base_dy,
			char = char,
			color = shadow_color,
			rotation = tile.rotation,
			natural_rotation = tile.natural_rotation,
			size_scale = 1 + (z - 1) * render_cfg.z_size_scale_per_level,
		})
	end

	emit_char({
		z = z + natural_height,
		y = y,
		layer = draw_buffer.LAYER.TILE_CHAR,
		x_screen = x_screen + dx,
		y_screen = y_screen + dy,
		char = char,
		color = scaled_color,
		outline_color = outline_color,
		rotation = tile.rotation,
		natural_rotation = tile.natural_rotation,
		size_scale = size_scale,
	})
end

function scene_drawer:emit_entity(entity, center_x, center_y, visible, explored)
	local tilelike = entities:get_tag_entity(entity, "tilelike")

	if not visible and not (tilelike and explored) then
		return
	end

	local base_color = entity.color

	if tilelike then
		base_color = render_utils.get_effective_color(base_color, visible, explored)
	end

	local outline_color = entity.outline_color
	base_color, outline_color = apply_bw_mode(base_color, outline_color)

	local x_screen, y_screen = render_utils.get_screen_coords(entity.x, entity.y, center_x, center_y)
	local base = render_utils.distance_scale(entity.x, entity.y, center_x, center_y)

	if entities:get_tag_entity(entity, "covers") then
		emit_cover_rect(draw_buffer.LAYER.ENTITY_COVER, entity.z, entity.y, x_screen, y_screen)
	end

	for i, char_data in ipairs(entity.chars) do
		local scale = render_utils.height_level_scale(entity.z + i, max_height, map.max_z, map.min_z, visible, base)
			+ render_cfg.entity_brightness_boost

		local scaled_color = render_utils.scale_color(base_color, scale)

		local dx, dy = get_offset(entity.z + i - 1, entity.x, entity.y, center_x, center_y)

		emit_char({
			z = entity.z + i - 1,
			y = entity.y,
			layer = draw_buffer.LAYER.ENTITY_CHAR,
			x_screen = x_screen + dx,
			y_screen = y_screen + dy,
			char = char_data,
			color = scaled_color,
			outline_color = outline_color,
			rotation = entity.rotation,
			natural_rotation = entity.natural_rotation,
			size_scale = 1 + (entity.z + i - 1) * render_cfg.z_size_scale_per_level,
		})
	end
end

function scene_drawer:draw_grid_overlay(start_x, start_y, end_x, end_y, camera_x, camera_y)
	if not debug_state.show_grid then
		return
	end

	for y = start_y, end_y do
		for x = start_x, end_x do
			local screen_x, screen_y = render_utils.get_screen_coords(x, y, camera_x, camera_y)
			render_primitives.draw_grid_cell(screen_x, screen_y)
		end
	end
end

function scene_drawer:reload_fonts()
	tile_size = config.tile_size
	small_tile_size = config.small_tile_size
	default_font = config.font
	small_font = config.small_font
	offset_amount = render_cfg.offset_amount_factor * tile_size
end

function scene_drawer:reload_settings()
	max_height = render_cfg.max_height
end

return scene_drawer
