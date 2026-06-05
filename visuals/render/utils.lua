local config = require("config.runtime")
local render_config = require("config.render_config")
local default_font
local tile_size
local render_utils = {}

function render_utils.height_level_scale(z, max_z, min_z, visible)
	local range = max_z - min_z
	local normalized = (z - min_z) / range

	local height_factor = 0.15 + (normalized ^ 2) * 0.9
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
		local e = render_config.lighting.explored_color
		return { e[1], e[2], e[3], e[4] }
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

local function clamp_to_unit(r, g, b)
	local m = math.max(r, g, b)
	if m > 1 then
		return r / m, g / m, b / m
	end
	return r, g, b
end

function render_utils.normalize_light(light)
	return clamp_to_unit(light.r or 0, light.g or 0, light.b or 0)
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

function render_utils.lighting_z_factor(sources, z)
	if not sources or not z then
		return 1
	end
	local weighted, total = 0, 0
	for _, src in ipairs(sources) do
		weighted = weighted + src.contribution * math.max(0, 1 - math.abs(z - src.z) * render_config.lighting.z_falloff)
		total = total + src.contribution
	end
	return total == 0 and 1 or weighted / total
end

function render_utils.apply_lighting(color, light, z)
	if not color then
		return { 1, 1, 1, 1 }
	end
	local ambient = render_config.lighting.ambient
	local emissive = render_config.lighting.light_emissive

	local z_factor = render_utils.lighting_z_factor(light.sources, z)
	local zr = (light.r or 0) * z_factor
	local zg = (light.g or 0) * z_factor
	local zb = (light.b or 0) * z_factor

	local fr, fg, fb = clamp_to_unit(ambient.r + zr, ambient.g + zg, ambient.b + zb)

	local lr, lg, lb = clamp_to_unit(zr, zg, zb)

	local r, g, b = clamp_to_unit(
		(color[1] or 1) * fr + lr * emissive,
		(color[2] or 1) * fg + lg * emissive,
		(color[3] or 1) * fb + lb * emissive
	)

	return { r, g, b, (color[4] or 1) }
end

function render_utils.tonemap(color)
	if not color then
		return { 1, 1, 1, 1 }
	end
	local r, g, b = clamp_to_unit(color[1] or 1, color[2] or 1, color[3] or 1)
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
