local config = require("config.runtime")
local render_config = require("config.render_config")
local time = require("engine.time")
local utils = require("utils")
local default_font
local tile_size
local render_utils = {}

local ambient_cache = { r = 0, g = 0, b = 0 }
local ambient_cache_t = nil

local function ambient_color()
	local t = time.time_of_day()
	if t == ambient_cache_t then
		return ambient_cache
	end

	local keys = render_config.lighting.ambient_keys
	local A, B
	for i = 1, #keys do
		if keys[i].at <= t then
			A, B = keys[i], keys[i + 1]
		else
			break
		end
	end
	local span, f
	if B then
		span = B.at - A.at
	else
		B, span = keys[1], (keys[1].at + 1.0) - A.at
	end
	f = span > 0 and (t - A.at) / span or 0

	ambient_cache.r = utils.lerp(A.color.r, B.color.r, f)
	ambient_cache.g = utils.lerp(A.color.g, B.color.g, f)
	ambient_cache.b = utils.lerp(A.color.b, B.color.b, f)
	ambient_cache_t = t
	return ambient_cache
end
function render_utils.height_level_scale(z, max_z, min_z, visible)
	local range = max_z - min_z
	local normalized = (z - min_z) / range

	local height_factor = 0.2 + (normalized ^ 2) * 0.9
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

function render_utils.tonemap(color)
	if not color then
		return { 1, 1, 1, 1 }
	end
	local r, g, b = clamp_to_unit(color[1] or 1, color[2] or 1, color[3] or 1)
	return { r, g, b, (color[4] or 1) }
end

local half_screen_x, half_screen_y = 0, 0
local max_dist = 1
local emissive_now, brighten_now, brighten_gamma = 1, 1, 1

function render_utils.get_screen_coords(x, y, center_x, center_y)
	return (x - center_x + half_screen_x) * tile_size, (y - center_y + half_screen_y) * tile_size
end

function render_utils.get_map_coords(screen_x, screen_y, center_x, center_y)
	local x = (screen_x - (love.graphics.getWidth() / 2)) / tile_size + center_x
	local y = (screen_y - (love.graphics.getHeight() / 2)) / tile_size + center_y
	return math.floor(x), math.floor(y)
end

function render_utils.distance_scale(x1, y1, x2, y2)
	if not render_config.lighting.distance_vignette then
		return 1
	end

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

function render_utils.desaturate(color, amount)
	local gray = render_utils.to_grayscale(color)
	return {
		utils.lerp(color[1], gray[1], amount),
		utils.lerp(color[2], gray[2], amount),
		utils.lerp(color[3], gray[3], amount),
		color[4],
	}
end

local keyframe_cache = setmetatable({}, { __mode = "k" })
local function sample_keyframes(keys, t)
	local cached = keyframe_cache[keys]
	if cached and cached.t == t then
		return cached.v
	end

	local A, B
	for i = 1, #keys do
		if keys[i].at <= t then
			A, B = keys[i], keys[i + 1]
		else
			break
		end
	end
	local span
	if B then
		span = B.at - A.at
	else
		B, span = keys[1], (keys[1].at + 1.0) - A.at
	end
	local f = span > 0 and (t - A.at) / span or 0

	local v = utils.lerp(A.v, B.v, f)
	if cached then
		cached.t, cached.v = t, v
	else
		keyframe_cache[keys] = { t = t, v = v }
	end
	return v
end

function render_utils.refresh_frame_cache()
	half_screen_x = love.graphics.getWidth() / tile_size / 2
	half_screen_y = love.graphics.getHeight() / tile_size / 2
	max_dist = math.sqrt(half_screen_x ^ 2 + half_screen_y ^ 2)
	local t = time.time_of_day()
	brighten_now = sample_keyframes(render_config.lighting.brightness_keys, t)
	emissive_now = sample_keyframes(render_config.lighting.emissive_keys, t)
	brighten_gamma = 1 / brighten_now
end

function render_utils.emissive_by_time()
	return emissive_now
end

function render_utils.get_gamma()
	return brighten_gamma
end

function render_utils.apply_lighting(color, light, emissive_scale)
	if not color then
		return { 1, 1, 1, 1 }
	end
	local ambient = ambient_color()
	local emissive = (emissive_scale or render_config.lighting.light_emissive) * render_utils.emissive_by_time()

	local zr = light.r or 0
	local zg = light.g or 0
	local zb = light.b or 0

	local fr, fg, fb = clamp_to_unit(ambient.r + zr, ambient.g + zg, ambient.b + zb)

	local lr, lg, lb = clamp_to_unit(zr, zg, zb)

	local r, g, b = clamp_to_unit(
		(color[1] or 1) * fr + lr * emissive,
		(color[2] or 1) * fg + lg * emissive,
		(color[3] or 1) * fb + lb * emissive
	)

	return { r, g, b, (color[4] or 1) }
end

function render_utils.load()
	tile_size = config.tile_size
	default_font = config.font
	render_utils.refresh_frame_cache()
end

function render_utils.scale_alpha(color, scale)
	return { color[1], color[2], color[3], color[4] * scale }
end

function render_utils.get_visual_state(entity)
	local alpha = 1
	local tint = { 1, 1, 1 }
	if entity.statuses then
		for _, status in ipairs(entity.statuses) do
			local v = status.visual
			if v then
				if v.alpha then
					alpha = alpha * v.alpha
				end
				if v.tint then
					tint[1] = tint[1] * (v.tint[1] or 1)
					tint[2] = tint[2] * (v.tint[2] or 1)
					tint[3] = tint[3] * (v.tint[3] or 1)
				end
			end
		end
	end

	if entity.anim and entity.anim.flash then
		local f = entity.anim.flash
		local p = f.elapsed / f.duration
		local v = f.visual
		if v.tint then
			for i = 1, 3 do
				tint[i] = tint[i] * utils.lerp(v.tint[i], 1, p)
			end
		end
		if v.alpha then
			alpha = alpha * utils.lerp(v.alpha, 1, p)
		end
	end

	return { alpha = alpha, tint = tint }
end

return render_utils
