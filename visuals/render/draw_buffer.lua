local render_primitives = require("visuals.render.primitives")
local config = require("config.runtime")

local draw_buffer = {
	PASS = {
		WORLD = 0,
		OVERLAY = 1,
	},
	LAYER = {
		TILE_COVER = 1,
		TILE_SHADOW = 2,
		TILE_CHAR = 3,
		EFFECT_BELOW_ENTITY = 5,
		ENTITY_COVER = 4,
		ENTITY_CHAR = 6,
		WEATHER = 7,
	},
}

local buf = {}

local function compare(a, b)
	local pa = a.pass or 0
	local pb = b.pass or 0
	if pa ~= pb then
		return pa < pb
	end
	if a.z ~= b.z then
		return a.z < b.z
	end
	if a.layer ~= b.layer then
		return a.layer < b.layer
	end
	if a.y ~= b.y then
		return a.y < b.y
	end

	return a.insertion_order < b.insertion_order
end

function draw_buffer:emit(entry)
	entry.insertion_order = #buf + 1
	buf[#buf + 1] = entry
end

function draw_buffer:clear()
	for i = #buf, 1, -1 do
		buf[i] = nil
	end
end

function draw_buffer:sort()
	table.sort(buf, compare)
end

function draw_buffer:walk()
	love.graphics.setFont(config.font)
	for i = 1, #buf do
		local d = buf[i]
		if d.kind == "char" then
			render_primitives.draw_char(
				d.x_screen,
				d.y_screen,
				d.char,
				d.color,
				d.outline_color,
				d.rotation,
				d.natural_rotation,
				d.size_scale
			)
		else
			render_primitives.draw_rect(
				d.x_screen,
				d.y_screen,
				d.w,
				d.h,
				d.color,
				d.outline_width,
				d.outline_color,
				d.rounded_amount
			)
		end
	end
end

return draw_buffer
