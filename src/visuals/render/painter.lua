local panels = require("src.visuals.ui.panels")
local render_utils = require("src.visuals.render.utils")
local utils = require("src.utils")
local map = require("src.map.map")
local render_primitives = require("src.visuals.render.primitives")
local config = require("src.config.runtime")
local render_cfg = require("src.config.render_config")
local debug_state = require("src.debug.debug_state")
local draw_buffer = require("src.visuals.render.draw_buffer")

local painter = {}

local PARTICLE_LAYERS = {
	below_entity = draw_buffer.LAYER.EFFECT_BELOW_ENTITY,
}

local EFFECT_LAYERS = {
	below_entity = draw_buffer.LAYER.EFFECT_BELOW_ENTITY,
	above_entity = draw_buffer.LAYER.EFFECT_ABOVE_ENTITY,
}

local ENTITY_LAYERS = {
	ground = draw_buffer.LAYER.ENTITY_GROUND,
}

local ENTITY_COVER_LAYERS = {
	ground = draw_buffer.LAYER.ENTITY_GROUND_COVER,
}

local tile_size
local small_tile_size
local small_font

local offset_amount

local function apply_bw_mode(r, g, b, a, outline_color, tier)
	if debug_state.bw_mode < tier then
		return r, g, b, a, outline_color
	end

	local nr, ng, nb, na = render_utils.grayscale_rgba(r, g, b, a)
	local oc = outline_color and render_utils.to_grayscale(outline_color) or nil
	return nr, ng, nb, na, oc
end

local function get_offset(z, x, y, cx, cy)
	return render_utils.get_offset(z, debug_state.offset_type, offset_amount, x, y, cx, cy)
end

local function emit_shadow(
	z,
	y,
	layer,
	x_screen,
	y_screen,
	char,
	r,
	g,
	b,
	a,
	rotation,
	natural_rotation,
	size_scale,
	mirror_facing
)
	local sr, sg, sb = render_utils.scale_rgba(r, g, b, a, render_cfg.lighting.shadow_brightness_scale)
	local sa = (a or 1) * render_cfg.lighting.shadow_alpha_scale
	draw_buffer:emit_char(
		nil,
		z,
		y,
		layer,
		x_screen,
		y_screen,
		char,
		sr,
		sg,
		sb,
		sa,
		nil,
		rotation,
		natural_rotation,
		size_scale,
		mirror_facing
	)
end

local function emit_name(
	z,
	y,
	layer,
	x_screen,
	y_screen,
	r,
	g,
	b,
	a,
	outline_color,
	rotation,
	natural_rotation,
	size_scale,
	name
)
	for i = 1, #name do
		draw_buffer:emit_char(
			nil,
			z,
			y,
			layer,
			x_screen + ((i - 1) * tile_size),
			y_screen,
			name:sub(i, i),
			r,
			g,
			b,
			a,
			outline_color,
			rotation,
			natural_rotation,
			size_scale,
			nil
		)
	end
end

local function emit_cover_rect(layer, z, y, x_screen, y_screen, r, g, b, a)
	draw_buffer:emit_rect(nil, z, y, layer, x_screen, y_screen, tile_size, tile_size, r, g, b, a, nil, nil, nil)
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

			local r, g, b, a
			if effect.params.decay_over_time then
				local ur, ug, ub, ua = render_utils.unpack_rgba(rect.colors[1])
				r, g, b, a = render_utils.scale_alpha_rgba(
					ur,
					ug,
					ub,
					ua,
					effect.params.lifespan / effect.params.initial_lifespan
				)
			else
				r, g, b, a = render_utils.unpack_rgba(rect.colors[((effect.params.i - 1) % #rect.colors) + 1])
			end

			local effect_size = rect.sizes[((effect.params.i - 1) % #rect.sizes) + 1] * tile_size

			draw_buffer:emit_rect(
				pass,
				effect.z,
				cy,
				draw_buffer.LAYER.EFFECT_BELOW_ENTITY,
				x_screen + ((tile_size - effect_size) / 2),
				y_screen + ((tile_size - effect_size) / 2),
				effect_size,
				effect_size,
				r,
				g,
				b,
				a,
				rect.outline_width,
				rect.outline_color,
				rect.rounded_amount
			)
		end
	end

	if effect.glyph then
		local px, py = render_utils.get_screen_coords(effect.x, effect.y, center_x, center_y)
		local r, g, b, a = render_utils.unpack_rgba(effect.glyph.color)

		if effect.params.decay_over_time then
			r, g, b, a = render_utils.scale_alpha_rgba(r, g, b, a, 1 - (effect.params.age / effect.params.duration))
		end
		draw_buffer:emit_char(
			pass,
			effect.z,
			effect.y,
			EFFECT_LAYERS[effect.layer] or draw_buffer.LAYER.EFFECT_BELOW_ENTITY,
			px,
			py,
			effect.glyph.char,
			r,
			g,
			b,
			a,
			nil,
			effect.r or 0,
			nil,
			effect.glyph.size,
			nil
		)
	end

	if effect.panels then
		local anchor_offset_x = effect.anchor and utils.get_center_of_footprint(effect.anchor) or 0

		for _, panel in ipairs(effect.panels) do
			local pr, pg, pb, pa = render_utils.unpack_rgba(panel.colors[effect.params.i])
			local size_scale = (panel.sizes and panel.sizes[effect.params.i]) or 1
			local rect_size = tile_size * size_scale

			local px, py = render_utils.get_screen_coords(
				(effect.anchor and utils.render_x(effect.anchor) + anchor_offset_x) or effect.x,
				(effect.anchor and utils.render_y(effect.anchor) - panel.offset_y) or effect.y,
				center_x,
				center_y
			)

			local pad = (rect_size - tile_size) / 2

			draw_buffer:emit_rect(
				pass,
				effect.z,
				effect.y,
				draw_buffer.LAYER.EFFECT_BELOW_ENTITY,
				px - pad,
				py - pad,
				rect_size,
				rect_size,
				pr,
				pg,
				pb,
				pa,
				panel.outline_width or 1,
				panel.outline_color,
				nil
			)

			for _, text in ipairs(panel.texts) do
				draw_buffer:emit_char(
					pass,
					effect.z,
					effect.y,
					draw_buffer.LAYER.EFFECT_BELOW_ENTITY,
					px,
					py,
					text,
					1,
					1,
					1,
					1,
					nil,
					nil,
					nil,
					size_scale,
					nil
				)
			end
		end
	end
end

local function resolve_screen_anchor(mode, screen_size, panel_size, margin)
	if mode == "center" then
		return (screen_size - panel_size) / 2 + (margin or 0)
	elseif mode == "end" then
		return screen_size - panel_size - (margin or 0)
	end
	return margin or 0
end

function painter:draw_panel(panel, center_x, center_y)
	if not panel.visible then
		return
	end
	love.graphics.setFont(panel.font or small_font)

	if panel.auto_size then
		panels:measure_auto_size(panel)
	end

	local visible_texts = panels:get_visible_texts(panel)

	local px, py = panel.x, panel.y

	local screen_anchor = panel.screen_anchor
	if screen_anchor then
		if screen_anchor.x then
			px = resolve_screen_anchor(screen_anchor.x, love.graphics.getWidth(), panel.width, screen_anchor.margin_x)
		end
		if screen_anchor.y then
			py = resolve_screen_anchor(screen_anchor.y, love.graphics.getHeight(), panel.height, screen_anchor.margin_y)
		end
	end

	local anchor_anim = panel.anchor and panel.anchor.anim
	if anchor_anim and anchor_anim.render_x and anchor_anim.render_y then
		px, py = render_utils.get_screen_coords(anchor_anim.render_x + 0.5, anchor_anim.render_y, center_x, center_y)
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
		panel.tile_size or small_tile_size,
		panel.center_vertical,
		panel.text_offset_x,
		panel.text_offset_y
	)
end

function painter:emit_tile_at_z(
	tile,
	x,
	y,
	z,
	center_x,
	center_y,
	visible,
	explored,
	time,
	x_screen,
	y_screen,
	base,
	light_data
)
	local char = tile.chars[1]
	local natural_height = tile.natural_height or 0
	local z_eff = z + natural_height

	local alpha = render_utils.height_level_scale(z_eff, map.max_z, map.min_z, visible)

	local br, bg, bb, ba = render_utils.effective_rgba(tile.color, visible, explored)
	local r, g, b, a = 1, 1, 1, 1
	if br then
		r, g, b, a = render_utils.scale_rgba(br, bg, bb, ba, alpha)
	end

	if visible then
		r, g, b, a = render_utils.apply_lighting_rgba(r, g, b, a, light_data)
		r, g, b, a = render_utils.apply_flicker_rgba(r, g, b, a, light_data.sources, time)
	end

	local outline_color = tile.outline_color

	r, g, b, a, outline_color = apply_bw_mode(r, g, b, a, outline_color, 1)

	r, g, b, a = render_utils.scale_rgba(r, g, b, a, base)
	r, g, b, a = render_utils.tonemap_rgba(r, g, b, a)

	local base_dx, base_dy = get_offset(z, x, y, center_x, center_y)

	if tile.covers or (z == 1 and not tile.transparent) then
		local cr, cg, cb, ca = 0, 0, 0, 1
		if visible then
			local lr, lg, lb = render_utils.normalize_light(light_data)
			local k = render_cfg.lighting.cover_emissive * render_utils.emissive_by_time()
			cr, cg, cb, ca = lr * k, lg * k, lb * k, 1
			cr, cg, cb, ca = render_utils.apply_flicker_rgba(cr, cg, cb, ca, light_data.sources, time)
		end
		cr, cg, cb, ca = render_utils.scale_rgba(cr, cg, cb, ca, base)
		emit_cover_rect(draw_buffer.LAYER.TILE_COVER, z, y, x_screen + base_dx, y_screen + base_dy, cr, cg, cb, ca)
	end

	local dx, dy = base_dx, base_dy
	local size_scale = 1 + (z_eff - 1) * render_cfg.rendering.z_size_scale_per_level

	if natural_height ~= 0 then
		dx, dy = get_offset(z_eff, x, y, center_x, center_y)

		emit_shadow(
			z,
			y,
			draw_buffer.LAYER.TILE_SHADOW,
			x_screen + base_dx,
			y_screen + base_dy,
			char,
			r,
			g,
			b,
			a,
			tile.rotation,
			tile.natural_rotation,
			1 + (z - 1) * render_cfg.rendering.z_size_scale_per_level,
			nil
		)
	end

	draw_buffer:emit_char(
		nil,
		z + natural_height,
		y,
		draw_buffer.LAYER.TILE_CHAR,
		x_screen + dx,
		y_screen + dy,
		char,
		r,
		g,
		b,
		a,
		outline_color,
		tile.rotation,
		tile.natural_rotation,
		size_scale,
		nil
	)
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
	local r, g, b, a = render_utils.unpack_rgba(p.color)
	r, g, b, a = render_utils.scale_rgba(r, g, b, a, alpha)
	local light_data = map:get_lighting_tile(tx, ty)
	if light_data then
		r, g, b, a = render_utils.apply_lighting_rgba(r, g, b, a, light_data, render_cfg.lighting.particle_emissive)
	end
	r, g, b, a = apply_bw_mode(r, g, b, a, nil, 2)

	r, g, b, a = render_utils.scale_rgba(r, g, b, a, render_utils.distance_scale(p.x, p.y, center_x, center_y))
	r, g, b, a = render_utils.tonemap_rgba(r, g, b, a)
	a = a * (p.alpha_mult or 1)
	draw_buffer:emit_char(
		nil,
		p.z,
		p.y,
		PARTICLE_LAYERS[p.layer] or draw_buffer.LAYER.WEATHER,
		x_screen + dx,
		y_screen + dy,
		p.char,
		r,
		g,
		b,
		a,
		nil,
		p.r,
		nil,
		(1 + (p.z - 1) * render_cfg.rendering.z_size_scale_per_level) * render_cfg.particles.size_scale,
		nil
	)
end

local function footprint_cells(entity)
	local ret = {}
	for _, c in ipairs(utils.footprint_offsets(entity)) do
		table.insert(ret, {
			render_x = utils.render_x(entity) + c.dx,
			x = entity.x + c.dx,
			render_y = utils.render_y(entity) + c.dy,
			y = entity.y + c.dy,
			char = c.char,
		})
	end
	return ret
end

function painter:emit_entity(entity, center_x, center_y, visible, explored, time)
	local tilelike = utils.get_tag(entity, "tilelike")

	local xray = debug_state.show_xray > 0 and (debug_state.show_xray >= 2 or not tilelike)
	if xray then
		explored = true
	end

	if not visible and not (tilelike and explored) and not xray then
		return
	end

	local outline_color = entity.outline_color
	if debug_state.bw_mode >= 2 and outline_color then
		outline_color = render_utils.to_grayscale(outline_color)
	end

	local visuals = render_utils.get_visual_state(entity)
	local natural_height = entity.natural_height or 0
	for _, entity_part in ipairs(footprint_cells(entity)) do
		local light_data = visible and map:get_lighting_tile(entity_part.x, entity_part.y) or nil

		local base = render_utils.distance_scale(entity_part.x, entity_part.y, center_x, center_y)
		local x_screen, y_screen =
			render_utils.get_screen_coords(entity_part.render_x, entity_part.render_y, center_x, center_y)
		if utils.get_tag(entity, "covers") then
			local cr, cg, cb, ca = 0, 0, 0, 1
			if visible then
				local rx = math.floor(entity_part.render_x)
				local ry = math.floor(entity_part.render_y)
				local cover_light = map:get_lighting_tile(rx, ry)
				local lr, lg, lb = render_utils.normalize_light(cover_light)
				local k = render_cfg.lighting.cover_emissive * render_utils.emissive_by_time()
				cr, cg, cb, ca = lr * k, lg * k, lb * k, 1
				cr, cg, cb, ca = render_utils.apply_flicker_rgba(cr, cg, cb, ca, cover_light.sources, time)
			end
			cr, cg, cb, ca = render_utils.scale_rgba(cr, cg, cb, ca, base)
			local cover_layer = ENTITY_COVER_LAYERS[entity.render_layer] or draw_buffer.LAYER.ENTITY_COVER
			emit_cover_rect(cover_layer, entity.z, entity_part.y, x_screen, y_screen, cr, cg, cb, ca)
		end

		local cell_chars = entity_part.char and { entity_part.char } or entity.appearance.chars
		for i, char_data in ipairs(cell_chars) do
			local base_color = entity.appearance.color[i] or entity.appearance.color[#entity.appearance.color]

			local br, bg, bb, ba
			if tilelike then
				br, bg, bb, ba = render_utils.effective_rgba(base_color, visible, explored)
			elseif base_color then
				br, bg, bb, ba = render_utils.unpack_rgba(base_color)
			end

			local z_eff = entity.z + i - 1 + natural_height
			local scale = render_utils.height_level_scale(z_eff, map.max_z, map.min_z, visible)
			if not tilelike then
				scale = scale + render_cfg.lighting.entity_brightness_boost
			end

			local r, g, b, a = 1, 1, 1, 1
			if br then
				r, g, b, a = render_utils.scale_rgba(br, bg, bb, ba, scale)
			end
			if light_data then
				r, g, b, a =
					render_utils.apply_lighting_rgba(r, g, b, a, light_data, render_cfg.lighting.entity_emissive)
				-- TODO: Determine if this should apply to entity colors
			end

			if visuals.tint then
				r, g, b, a = render_utils.tint_rgba(r, g, b, a, visuals.tint)
			end
			if visuals.alpha then
				r, g, b, a = render_utils.scale_rgba(r, g, b, a, visuals.alpha)
			end
			r, g, b, a = apply_bw_mode(r, g, b, a, nil, 2)

			r, g, b, a = render_utils.scale_rgba(r, g, b, a, base)
			r, g, b, a = render_utils.tonemap_rgba(r, g, b, a)

			local dx, dy = get_offset(
				utils.render_z(entity) + i - 1 + natural_height,
				entity_part.x,
				entity_part.y,
				center_x,
				center_y
			)

			local entity_layer = ENTITY_LAYERS[entity.render_layer] or draw_buffer.LAYER.ENTITY_CHAR
			local char_size_scale = 1
				+ (utils.render_z(entity) + i - 1 + natural_height) * render_cfg.rendering.z_size_scale_per_level

			if entity.moused and entity.type == "actor" and not entity.footprint then
				emit_name(
					z_eff,
					entity_part.y,
					entity_layer,
					x_screen + dx,
					y_screen + dy,
					r,
					g,
					b,
					a,
					outline_color,
					entity.rotation,
					entity.natural_rotation,
					char_size_scale,
					entity.name
				)
				break
			else
				if natural_height ~= 0 then
					local base_dx, base_dy =
						get_offset(utils.render_z(entity) + i - 1, entity_part.x, entity_part.y, center_x, center_y)
					emit_shadow(
						z_eff,
						entity_part.y,
						draw_buffer.LAYER.ENTITY_SHADOW,
						x_screen + base_dx,
						y_screen + base_dy,
						char_data,
						r,
						g,
						b,
						a,
						entity.rotation,
						entity.natural_rotation,
						1 + (utils.render_z(entity) + i - 1) * render_cfg.rendering.z_size_scale_per_level,
						entity.mirror_facing
					)
				end
				draw_buffer:emit_char(
					nil,
					z_eff,
					entity_part.y,
					entity_layer,
					x_screen + dx,
					y_screen + dy,
					char_data,
					r,
					g,
					b,
					a,
					outline_color,
					entity.rotation,
					entity.natural_rotation,
					char_size_scale,
					entity.mirror_facing
				)
			end
		end
	end
end

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

	render_primitives.draw_screen_center_lines()
end

function painter:reload_fonts()
	tile_size = config.tile_size
	small_tile_size = config.small_tile_size
	small_font = config.small_font
	offset_amount = render_cfg.rendering.offset_amount_factor * tile_size
end

return painter
