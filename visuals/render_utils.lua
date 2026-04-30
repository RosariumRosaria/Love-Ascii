local config = require("config")
local render_config = require("config.render_config")
local default_font
local tile_size
local render_utils = {}

function render_utils.height_level_scale(z, max_height, max_z, min_z, visible, base)
	local range = max_z - min_z
	local normalized = (z - min_z) / range
	local height_factor = 0.25 + normalized * 1.25
	local alpha = height_factor * base
	if not visible then
		alpha = alpha * 0.5
	end

	return math.max(math.min(alpha, 2), 0.05)
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

-- Returns the final color to be used based on visibility and exploration
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
		return { 0.961, 0.871, 0.702, 1 } -- fog-of-war color
	end
	return nil
end

-- Takes a color and scales it by a set amount.
-- If no color is provided, defaults to white.
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

-- Converts XY map to XY screen coordinates based on camera center
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
	return math.min(math.max(linear ^ render_config.distance_drama, 0.05), 1)
end

-- Gets a visual offset based on height and offset type
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

function render_utils.get_visual_center_from_top(font, ch)
	local per_font = glyph_center_cache[font]
	if not per_font then
		per_font = {}
		glyph_center_cache[font] = per_font
	end
	if per_font[ch] then
		return per_font[ch]
	end

	local pad = 4
	local line_height = font:getHeight()
	local w = math.max(8, math.ceil(font:getWidth(ch)) + pad * 2)
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
	for y = 0, h - 1 do
		local row_has_ink = false
		for x = 0, w - 1 do
			local _, _, _, a = img:getPixel(x, y)
			if a > 0 then
				row_has_ink = true
				break
			end
		end
		if row_has_ink then
			if y < top then
				top = y
			end
			if y > bottom then
				bottom = y
			end
		end
	end

	local center_from_top
	if bottom >= top then
		center_from_top = (top + bottom) * 0.5 - pad
	else
		center_from_top = line_height * 0.5
	end

	per_font[ch] = center_from_top
	return center_from_top
end

function render_utils.to_grayscale(color)
	local l = color[1] * 0.299 + color[2] * 0.587 + color[3] * 0.114
	return { l, l, l, color[4] }
end

function render_utils.brighten(color)
	local g = 1 / render_config.brightness
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
