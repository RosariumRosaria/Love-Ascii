local render_primitives = require("visuals.render.primitives")
local config = require("config.runtime")

local draw_buffer = {
	LAYER = {
		TILE_COVER = 1, -- opaque background rect (tile.covers)
		TILE_SHADOW = 2, -- shadow char under a natural_height tile
		TILE_CHAR = 3, -- main tile char
		EFFECT_BELOW_ENTITY = 5, -- buffered effects (e.g. trails) above tiles but under entities
		ENTITY_COVER = 4, -- black bg rect for entities with `covers` tag
		ENTITY_CHAR = 6, -- main entity char
		WEATHER = 7,
	},
}

local buf = {}

local function compare(a, b)
	if a.z ~= b.z then
		return a.z < b.z
	end
	if a.layer ~= b.layer then --TODO was reordingt these the rpoper fix
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
