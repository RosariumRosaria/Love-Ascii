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
		EFFECT_ABOVE_ENTITY = 7,
		WEATHER = 8,
	},
}

local buf = {}
local keys = {}

local Y_W = 2 ^ 18
local ORDER_W = 2 ^ 17
local floor = math.floor

function draw_buffer:emit(entry)
	local n = #buf + 1
	buf[n] = entry
	local zq = floor((entry.z + 16) * 64)
	local yq = floor((entry.y + 2) * 256)
	keys[n] = ((((entry.pass or 0) * 4096 + zq) * 16 + entry.layer) * Y_W + yq) * ORDER_W + n
end

function draw_buffer:clear()
	for i = #buf, 1, -1 do
		buf[i] = nil
		keys[i] = nil
	end
end

function draw_buffer:sort()
	table.sort(keys)
end

function draw_buffer:walk()
	love.graphics.setFont(config.font)
	for i = 1, #keys do
		local d = buf[keys[i] % ORDER_W]
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
