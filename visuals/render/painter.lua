local panels = require("visuals.panels")
local entities = require("entities.entities")
local render_utils = require("visuals.render.utils")
local map = require("map.map")
local render_primitives = require("visuals.render.primitives")
local config = require("config.runtime")
local render_cfg = require("config.render_config")
local debug_state = require("debug.debug_state")
local draw_buffer = require("visuals.render.draw_buffer")
local statuses = require("statuses.statuses")

local painter = {}

local tile_size
local small_tile_size
local small_font

local offset_amount

local function apply_bw_mode(color, outline_color, tier)
	if debug_state.bw_mode < tier then
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
		pass = params.pass,
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

local function emit_name(params, name)
	for i = 1, #name do
		local char = name:sub(i, i)
		draw_buffer:emit({
			z = params.z,
			y = params.y,
			layer = params.layer,
			kind = "char",
			x_screen = params.x_screen + ((i - 1) * tile_size),
			y_screen = params.y_screen,
			char = char,
			color = params.color,
			outline_color = params.outline_color,
			rotation = params.rotation,
			natural_rotation = params.natural_rotation,
			size_scale = params.size_scale,
		})
	end
end

local function emit_cover_rect(layer, z, y, x_screen, y_screen, color)
	draw_buffer:emit({
		z = z,
		y = y,
		layer = layer,
		kind = "rect",
		x_screen = x_screen,
		y_screen = y_screen,
		color = color,
		w = tile_size,
		h = tile_size,
	})
end

function painter:emit_effect(effect, center_x, center_y, visible)
	if not (visible or not effect.params.needs_to_be_seen) then
		return
	end

	local pass = effect.params.buffered and draw_buffer.PASS.WORLD or draw_buffer.PASS.OVERLAY

	if effect.rects then
		for _, rect in ipairs(effect.rects) do
			local cx, cy = effect.x + (rect.ox or 0), effect.y + (rect.oy or 0)
			local x_screen, y_screen = render_utils.get_screen_coords(cx, cy, center_x, center_y)

			local color
			if effect.params.decay_over_time then
				color =
					render_utils.scale_color(rect.colors[1], effect.params.lifespan / effect.params.initial_lifespan)
			else
				color = rect.colors[((effect.params.i - 1) % #rect.colors) + 1]
			end

			local effect_size = rect.sizes[((effect.params.i - 1) % #rect.sizes) + 1] * tile_size

			draw_buffer:emit({
				pass = pass,
				z = effect.z,
				y = cy, -- sort by the rect's own row
				layer = draw_buffer.LAYER.EFFECT_BELOW_ENTITY,
				kind = "rect",
				x_screen = x_screen + ((tile_size - effect_size) / 2),
				y_screen = y_screen + ((tile_size - effect_size) / 2),
				w = effect_size,
				h = effect_size,
				color = color,
				outline_width = rect.outline_width,
				outline_color = rect.outline_color,
				rounded_amount = rect.rounded_amount,
			})
		end
	end

	if effect.panels then
		for _, panel in ipairs(effect.panels) do
			local color = panel.colors[effect.params.i] or { 1, 1, 1, 1 }
			local size_scale = (panel.sizes and panel.sizes[effect.params.i]) or 1
			local rect_size = tile_size * size_scale

			local px, py = render_utils.get_screen_coords(
				(effect.anchor and effect.anchor.render_x) or effect.x,
				(effect.anchor and effect.anchor.render_y - panel.offset_y) or effect.y,
				center_x,
				center_y
			)

			local pad = (rect_size - tile_size) / 2

			draw_buffer:emit({
				pass = pass,
				z = effect.z,
				y = effect.y,
				layer = draw_buffer.LAYER.EFFECT_BELOW_ENTITY,
				kind = "rect",
				x_screen = px - pad,
				y_screen = py - pad,
				w = rect_size,
				h = rect_size,
				color = color,
				outline_width = panel.outline_width or 1,
				outline_color = panel.outline_color,
			})

			for _, text in ipairs(panel.texts) do
				emit_char({
					pass = pass,
					z = effect.z,
					y = effect.y,
					layer = draw_buffer.LAYER.EFFECT_BELOW_ENTITY,
					x_screen = px,
					y_screen = py,
					char = text,
					color = { 1, 1, 1, 1 },
					size_scale = size_scale,
				})
			end
		end
	end
end

function painter:draw_panel(panel, center_x, center_y)
	if not panel.visible then
		return
	end
	love.graphics.setFont(panel.font or small_font)

	local line_height = panel.tile_size or small_tile_size

	if panel.auto_size then
		local pad = (panel.outline_width or 1) + line_height * 0.25
		panel.width = render_utils.get_max_text_width(panel.texts, panel.font) + pad * 2
		panel.height = #panel.texts * line_height + pad * 2
	end

	local visible_texts = panels:get_visible_texts(panel)

	local px, py = panel.x, panel.y

	if panel.anchor and panel.anchor.render_x and panel.anchor.render_y then
		px, py = render_utils.get_screen_coords(panel.anchor.render_x + 0.5, panel.anchor.render_y, center_x, center_y)
		py = py - panel.height - panel.offset_y
		px = px - panel.width / 2
	end
	render_primitives.draw_panel(
		px,
		py,
		panel.width,
		panel.height,
		panel.color,
		panel.outline_width,
		panel.outline_color,
		visible_texts,
		panel.center_text,
		{ 1, 1, 1, 1 },
		panel.tile_size or small_tile_size
	)
end

function painter:emit_tile_at_z(tile, x, y, z, center_x, center_y, visible, explored, time)
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

	local alpha = render_utils.height_level_scale(z_eff, map.max_z, map.min_z, visible)

	local base_color = render_utils.get_effective_color(tile.color, visible, explored)
	local scaled_color = render_utils.scale_color(base_color, alpha)
	local light_data = map:get_lighting_tile(x, y)

	if visible then
		scaled_color = render_utils.apply_lighting(scaled_color, light_data, z)
		scaled_color = render_utils.apply_flicker(scaled_color, light_data.sources, time)
	end

	local outline_color = tile.outline_color

	scaled_color, outline_color = apply_bw_mode(scaled_color, outline_color, 1)

	scaled_color = render_utils.scale_color(scaled_color, base)
	scaled_color = render_utils.tonemap(scaled_color)

	local base_dx, base_dy = get_offset(z, x, y, center_x, center_y)

	if tile.covers or (z == 1 and not tile.transparent) then
		local cover_color = { 0, 0, 0, 1 }
		if visible then
			local r, g, b = render_utils.normalize_light(light_data)
			local k = render_cfg.lighting.cover_emissive * render_utils.emissive_by_time()
			cover_color = { r * k, g * k, b * k, 1 }
			cover_color = render_utils.apply_flicker(cover_color, light_data.sources, time)
		end
		cover_color = render_utils.scale_color(cover_color, base)
		emit_cover_rect(draw_buffer.LAYER.TILE_COVER, z, y, x_screen + base_dx, y_screen + base_dy, cover_color)
	end

	local dx, dy = base_dx, base_dy
	local size_scale = 1 + (z_eff - 1) * render_cfg.rendering.z_size_scale_per_level

	if tile.natural_height then
		dx, dy = get_offset(z_eff, x, y, center_x, center_y)

		local shadow_color = render_utils.scale_color(scaled_color, render_cfg.lighting.shadow_brightness_scale)

		shadow_color[4] = (scaled_color[4] or 1) * render_cfg.lighting.shadow_alpha_scale

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
			size_scale = 1 + (z - 1) * render_cfg.rendering.z_size_scale_per_level,
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

function painter:emit_particle(p, center_x, center_y, time)
	if p.delay and p.delay > 0 then
		return
	end
	local tx, ty = math.floor(p.x), math.floor(p.y)
	if ty < 1 or ty > map:get_max_y() or tx < 1 or tx > map:get_max_x() then
		return
	end
	if not map:is_visible(tx, ty) then
		return
	end

	local x_screen, y_screen = render_utils.get_screen_coords(p.x, p.y, center_x, center_y)
	local dx, dy = get_offset(p.z, p.x, p.y, center_x, center_y)

	local alpha = render_utils.height_level_scale(p.z, map.max_z, map.min_z, true)
	local scaled_color = render_utils.scale_color(p.color, alpha)
	local light_data = map:get_lighting_tile(tx, ty)
	if light_data then
		scaled_color = render_utils.apply_lighting(scaled_color, light_data, p.z)
	end
	scaled_color = apply_bw_mode(scaled_color, nil, 2)

	scaled_color = render_utils.scale_color(scaled_color, render_utils.distance_scale(p.x, p.y, center_x, center_y))
	scaled_color = render_utils.tonemap(scaled_color)
	scaled_color[4] = scaled_color[4] * (p.alpha_mult or 1)
	emit_char({
		z = p.z,
		y = p.y,
		layer = draw_buffer.LAYER.WEATHER,
		x_screen = x_screen + dx,
		y_screen = y_screen + dy,
		char = p.char,
		color = scaled_color,
		size_scale = (1 + (p.z - 1) * render_cfg.rendering.z_size_scale_per_level) * render_cfg.particles.size_scale,
	})
end

function painter:emit_entity(entity, center_x, center_y, visible, explored, time)
	local tilelike = entities.get_tag(entity, "tilelike")

	local xray = debug_state.show_xray and not tilelike

	if not visible and not (tilelike and explored) and not xray then
		return
	end

	local outline_color = entity.outline_color
	if debug_state.bw_mode >= 2 and outline_color then
		outline_color = render_utils.to_grayscale(outline_color)
	end

	local light_data = visible and map:get_lighting_tile(entity.x, entity.y) or nil

	local x_screen, y_screen = render_utils.get_screen_coords(entity.render_x, entity.render_y, center_x, center_y)
	local base = render_utils.distance_scale(entity.x, entity.y, center_x, center_y)

	if entities.get_tag(entity, "covers") then
		local cover_color = { 0, 0, 0, 1 }
		if visible then
			local rx = math.floor(entity.render_x)
			local ry = math.floor(entity.render_y)
			local cover_light = map:get_lighting_tile(rx, ry)
			local r, g, b = render_utils.normalize_light(cover_light)
			local k = render_cfg.lighting.cover_emissive * render_utils.emissive_by_time()
			cover_color = { r * k, g * k, b * k, 1 }
		end
		cover_color = render_utils.scale_color(cover_color, base)
		emit_cover_rect(draw_buffer.LAYER.ENTITY_COVER, entity.z, entity.y, x_screen, y_screen, cover_color)
	end

	for i, char_data in ipairs(entity.appearance.chars) do
		local base_color = entity.appearance.color[i] or entity.appearance.color[#entity.appearance.color]

		if tilelike then
			base_color = render_utils.get_effective_color(base_color, visible, explored)
		end

		local scale = render_utils.height_level_scale(entity.z + i - 1, map.max_z, map.min_z, visible)
		if not tilelike then
			scale = scale + render_cfg.lighting.entity_brightness_boost
		end

		local scaled_color = render_utils.scale_color(base_color, scale)
		if light_data then
			scaled_color = render_utils.apply_lighting(scaled_color, light_data, entity.z + i - 1)
			-- TODO: Determine if this should apply to entity colors
			-- scaled_color = render_utils.apply_flicker(scaled_color, light_data.flicker, time)
		end
		local visuals = statuses.get_visual_state(entity)
		if visuals.tint then
			scaled_color = render_utils.tint_color(scaled_color, visuals.tint)
		end
		if visuals.alpha then
			scaled_color = render_utils.scale_color(scaled_color, visuals.alpha)
		end
		scaled_color = apply_bw_mode(scaled_color, nil, 2)

		scaled_color = render_utils.scale_color(scaled_color, base)
		scaled_color = render_utils.tonemap(scaled_color)

		local dx, dy = get_offset(entity.z + i - 1, entity.x, entity.y, center_x, center_y)
		local p = {
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
			size_scale = 1 + (entity.z + i - 1) * render_cfg.rendering.z_size_scale_per_level,
		}
		if entity.moused and entity.type == "actor" then
			emit_name(p, entity.name)
			break
		else
			emit_char(p)
		end
	end
end

-- Debug-only overlay, drawn directly (not through draw_buffer).
function painter:draw_grid_overlay(start_x, start_y, end_x, end_y, camera_x, camera_y)
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

function painter:reload_fonts()
	tile_size = config.tile_size
	small_tile_size = config.small_tile_size
	small_font = config.small_font
	offset_amount = render_cfg.rendering.offset_amount_factor * tile_size
end

return painter
