local config = require("config.runtime")
local render_config = require("config.render_config")
local debug_state = require("debug.debug_state")
local default_font
local tile_size
local render_utils = {}

function render_utils.height_level_scale(z, max_height, max_z, min_z, visible)
	local range = max_z - min_z
	local normalized = (z - min_z) / range
	local height_factor = 0.1 + (normalized ^ 2) * 2.9
	local alpha = height_factor
	if not visible then
		alpha = alpha * 0.5
	end

	return math.max(math.min(alpha, z), 0.25)
end

function render_utils.get_max_text_width(texts, font)
	local max_width = 0
	font = font or default_font
	for _, text in ipairs(texts) do
		local curr_width = font:getWidth(text)
		if curr_width > max_width then
			max_width = curr_width
		end
	end
	return max_width
end

function render_utils.get_effective_color(color, visible, explored)
	if visible then
		if color then
			return {
				(color[1] or 1),
				(color[2] or 1),
				(color[3] or 1),
				(color[4] or 1),
			}
		else
			return { 1, 1, 1, 1 }
		end
	elseif explored then
		return { 0.861, 0.771, 0.502, 0.33 } --TODO: extract to config
	end
	return nil
end

function render_utils.scale_color(color, scale)
	if color then
		return {
			(color[1] or 1) * scale,
			(color[2] or 1) * scale,
			(color[3] or 1) * scale,
			(color[4] or 1),
		}
	else
		return { 1, 1, 1, 1 }
	end
end

function render_utils.tint_color(color, tint)
	if not color then
		return { 1, 1, 1, 1 }
	end
	if not tint then
		return color
	end
	return {
		(color[1] or 1) * (tint[1] or 1),
		(color[2] or 1) * (tint[2] or 1),
		(color[3] or 1) * (tint[3] or 1),
		(color[4] or 1),
	}
end

function render_utils.normalize_light(light)
	local r = light.r or 0
	local g = light.g or 0
	local b = light.b or 0
	local m = math.max(r, g, b)
	if m > 1 then
		return r / m, g / m, b / m
	end
	return r, g, b
end

function render_utils.apply_flicker(color, sources, t)
	if not sources or #sources == 0 then
		return color
	end
	local mod_sum = 0
	local total = 0
	for i = 1, #sources do
		local src = sources[i]
		local local_mod = 1
		local f = src.flicker
		if f then
			local_mod = 1 + f.amp * math.sin(t * f.freq + f.phase)
		end
		mod_sum = mod_sum + src.contribution * local_mod
		total = total + src.contribution
	end
	if total == 0 then
		return color
	end
	return render_utils.scale_color(color, mod_sum / total)
end

function render_utils.apply_lighting(color, light)
	if not color then
		return { 1, 1, 1, 1 }
	end
	local ambient = render_config.lighting.ambient
	local emissive = render_config.lighting.light_emissive

	local fr = ambient + (light.r or 0)
	local fg = ambient + (light.g or 0)
	local fb = ambient + (light.b or 0)
	local m = math.max(fr, fg, fb)
	if m > 1 then
		fr, fg, fb = fr / m, fg / m, fb / m
	end

	local lr, lg, lb = render_utils.normalize_light(light)

	local r = (color[1] or 1) * fr + lr * emissive
	local g = (color[2] or 1) * fg + lg * emissive
	local b = (color[3] or 1) * fb + lb * emissive

	if debug_state.normalize_lighting then
		local m = math.max(r, g, b)
		if m > 1 then
			r, g, b = r / m, g / m, b / m
		end
	else
		r = math.min(1, r)
		g = math.min(1, g)
		b = math.min(1, b)
	end

	return { r, g, b, (color[4] or 1) }
end

function render_utils.get_screen_coords(x, y, center_x, center_y)
	local screen_x = (x - center_x + love.graphics.getWidth() / tile_size / 2) * tile_size
	local screen_y = (y - center_y + love.graphics.getHeight() / tile_size / 2) * tile_size
	return screen_x, screen_y
end

function render_utils.distance_scale(x1, y1, x2, y2)
	local screen_width = love.graphics.getWidth()
	local screen_height = love.graphics.getHeight()

	local tiles_wide = screen_width / tile_size
	local tiles_high = screen_height / tile_size

	local max_dist = math.sqrt((tiles_wide / 2) ^ 2 + (tiles_high / 2) ^ 2)
	local dist = math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)

	local linear = math.max(1 - (dist / max_dist), 0)
	return math.min(math.max(linear ^ render_config.lighting.distance_drama, 0.05), 1)
end

function render_utils.get_offset(i, offset_type, offset, x, y, center_x, center_y)
	if offset_type == 1 then
		local scale = 0.1
		return (i - 1) * offset * (x - center_x) * scale, (i - 1) * offset * (y - center_y) * scale
	elseif offset_type == 2 then
		return -(i - 1) * offset, -(i - 1) * offset
	end
	return 0, 0
end

local glyph_center_cache = setmetatable({}, { __mode = "k" })

function render_utils.get_visual_center(font, ch)
	local per_font = glyph_center_cache[font]
	if not per_font then
		per_font = {}
		glyph_center_cache[font] = per_font
	end
	local cached = per_font[ch]
	if cached then
		return cached[1], cached[2]
	end

	local pad = 4
	local line_height = font:getHeight()
	local advance = math.ceil(font:getWidth(ch))
	local w = math.max(8, advance + pad * 2)
	local h = line_height + pad * 2

	local canvas = love.graphics.newCanvas(w, h)
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setFont(font)
	love.graphics.print(ch, pad, pad)
	love.graphics.setCanvas()
	love.graphics.pop()

	local img = canvas:newImageData()
	local top, bottom = h, -1
	local left, right = w, -1
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local _, _, _, a = img:getPixel(x, y)
			if a > 0 then
				if y < top then
					top = y
				end
				if y > bottom then
					bottom = y
				end
				if x < left then
					left = x
				end
				if x > right then
					right = x
				end
			end
		end
	end

	local center_from_top, center_from_left
	if bottom >= top then
		center_from_top = (top + bottom + 1) * 0.5 - pad
		center_from_left = (left + right + 1) * 0.5 - pad
	else
		center_from_top = line_height * 0.5
		center_from_left = advance * 0.5
	end

	per_font[ch] = { center_from_left, center_from_top }
	return center_from_left, center_from_top
end

function render_utils.to_grayscale(color)
	local l = color[1] * 0.299 + color[2] * 0.587 + color[3] * 0.114
	return { l, l, l, color[4] }
end

function render_utils.brighten(color)
	local g = 1 / render_config.lighting.brightness
	return {
		color[1] ^ g,
		color[2] ^ g,
		color[3] ^ g,
		color[4],
	}
end

function render_utils.load()
	tile_size = config.tile_size
	default_font = config.font
end

return render_utils
