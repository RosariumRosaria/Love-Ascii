local config = require("config.runtime")
local render_cfg = require("config.render_config")
local tile_size
local render_utils = require("visuals.render.utils")
local render_primitives = {}

function render_primitives.draw_rect(
	x_screen,
	y_screen,
	width,
	height,
	color,
	outline_width,
	outline_color,
	rounded_amount
)
	local rounded_amount_x = 0
	local rounded_amount_y = 0

	if rounded_amount then
		rounded_amount_x = width * rounded_amount
		rounded_amount_y = height * rounded_amount
	end

	love.graphics.setColor(color)
	love.graphics.rectangle("fill", x_screen, y_screen, width, height, rounded_amount_x, rounded_amount_y)

	if outline_width and outline_color then
		love.graphics.setLineWidth(outline_width)
		love.graphics.setColor(outline_color)
		love.graphics.rectangle(
			"line",
			x_screen - outline_width / 2,
			y_screen - outline_width / 2,
			width + outline_width,
			height + outline_width,
			rounded_amount_x,
			rounded_amount_y
		)
		love.graphics.setLineWidth(1)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function render_primitives.draw_char(
	x_screen,
	y_screen,
	text,
	color,
	outline_color,
	rotation,
	natural_rotation,
	size_scale,
	mirror_facing
)
	if not text or text == "" then
		return
	end

	local font = love.graphics.getFont()
	local center_from_left, center_from_top = render_utils.get_visual_center(font, text)

	local cx = x_screen + tile_size * 0.5
	local cy = y_screen + tile_size * 0.5

	local rot = (rotation or 0) % 360
	local nat = natural_rotation or 0
	local rads = math.rad((rot - nat) % 360)
	local s = size_scale or 1
	local sx, sy = s, s

	if mirror_facing and (rot - nat) % 360 ~= 0 then
		if rot == 180 then
			rads = math.rad(nat % 360)
			sx = -s
		elseif rot == 270 then
			rads = math.rad((nat - 90) % 360)
			sy = -s
		end
	end

	local ox = center_from_left
	local oy = center_from_top

	if outline_color then
		love.graphics.setColor(outline_color)
		love.graphics.print(text, cx + 1, cy + 1, rads, sx, sy, ox, oy)
	end

	love.graphics.setColor(color)
	love.graphics.print(text, cx, cy, rads, sx, sy, ox, oy)

	love.graphics.setColor(1, 1, 1, 1)
end

function render_primitives.draw_text_block(texts, x_screen, y_screen, width, outline, center_text, color, line_height)
	local font = love.graphics.getFont()
	line_height = line_height or tile_size
	if color then
		love.graphics.setColor(color)
	end

	for i, text in ipairs(texts) do
		local offset = outline * 2
		local dx = (center_text and (width - font:getWidth(text)) / 2) or offset
		local draw_x = x_screen + dx
		local draw_y = y_screen + outline + offset + ((i - 1) * line_height)

		love.graphics.print(text, draw_x, draw_y)
	end
end

function render_primitives.draw_panel(
	x_screen,
	y_screen,
	width,
	height,
	fill_color,
	outline_width,
	outline_color,
	texts,
	center_text,
	text_color,
	line_height
)
	render_primitives.draw_rect(x_screen, y_screen, width, height, fill_color, outline_width, outline_color)
	render_primitives.draw_text_block(
		texts,
		x_screen,
		y_screen,
		width,
		1,
		center_text,
		text_color or { 1, 1, 1, 1 },
		line_height
	)
end

function render_primitives.draw_grid_cell(x_screen, y_screen)
	love.graphics.setColor(render_cfg.debug.grid_color)
	love.graphics.rectangle("line", x_screen, y_screen, tile_size, tile_size)

	local cx = x_screen + tile_size * 0.5
	local dash = tile_size / 8
	for i = 0, 7, 2 do
		love.graphics.line(cx, y_screen + i * dash, cx, y_screen + (i + 1) * dash)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function render_primitives.draw_sight_ring(x_screen, y_screen, radius_tiles)
	local cx = x_screen + tile_size * 0.5
	local cy = y_screen + tile_size * 0.5
	love.graphics.setColor(render_cfg.debug.sight_color)
	love.graphics.circle("line", cx, cy, radius_tiles * tile_size)
	love.graphics.setColor(1, 1, 1, 1)
end

function render_primitives.load()
	tile_size = config.tile_size
end

return render_primitives
