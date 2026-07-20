local render_primitives = require("visuals.render.primitives")
local config = require("config.runtime")
local game_cfg = require("config.game_config")

local draw_buffer = {
	PASS = {
		WORLD = 0,
		OVERLAY = 1,
	},
	LAYER = {
		TILE_COVER = 1,
		TILE_SHADOW = 2,
		TILE_CHAR = 3,
		ENTITY_GROUND_COVER = 4,
		ENTITY_GROUND = 5,
		ENTITY_COVER = 6,
		ENTITY_SHADOW = 7,
		EFFECT_BELOW_ENTITY = 8,
		ENTITY_CHAR = 9,
		EFFECT_ABOVE_ENTITY = 10,
		WEATHER = 11,
	},
}

local buf = {}
local keys = {}
local count = 0

-- Entries sort by a single packed double: pass | z | layer | y | insertion order.
-- The field widths multiplied together must stay within 2^53 (the exact-integer
-- range of a double) or table.sort and the % decode in walk stop being exact.
local Z_MIN = game_cfg.map.min_z
local Z_SLOTS = 4096 -- z - Z_MIN in 1/64 steps: z must stay in [Z_MIN, Z_MIN + 64)
local LAYER_SLOTS = 16
local Y_MIN = -2
local Y_SLOTS = 2 ^ 18 -- y - Y_MIN in 1/256 steps: y must stay in [Y_MIN, Y_MIN + 1024)
local ORDER_W = 2 ^ 17 -- max draw entries per frame
assert(2 * Z_SLOTS * LAYER_SLOTS * Y_SLOTS * ORDER_W <= 2 ^ 53, "draw_buffer: packed sort key exceeds double precision")

local floor = math.floor

function draw_buffer:emit(entry)
	local n = count + 1
	if n >= ORDER_W then
		error("draw_buffer: exceeded " .. (ORDER_W - 1) .. " entries in one frame")
	end
	count = n
	buf[n] = entry
	-- Out-of-range coords (e.g. effect fringes past the map edge) clamp to the
	-- band edge so they mis-sort locally instead of corrupting adjacent fields.
	local zq = floor((entry.z - Z_MIN) * 64)
	if zq < 0 then
		zq = 0
	elseif zq >= Z_SLOTS then
		zq = Z_SLOTS - 1
	end
	local yq = floor((entry.y - Y_MIN) * 256)
	if yq < 0 then
		yq = 0
	elseif yq >= Y_SLOTS then
		yq = Y_SLOTS - 1
	end
	keys[n] = ((((entry.pass or 0) * Z_SLOTS + zq) * LAYER_SLOTS + entry.layer) * Y_SLOTS + yq) * ORDER_W + n
end

function draw_buffer:clear()
	count = 0
end

function draw_buffer:sort()
	-- Trim last frame's key tail so #keys matches this frame; buf slots past
	-- count are left in place and overwritten by future emits.
	for i = #keys, count + 1, -1 do
		keys[i] = nil
	end
	table.sort(keys)
end

function draw_buffer:walk()
	love.graphics.setFont(config.font)
	for i = 1, count do
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
				d.size_scale,
				d.mirror_facing
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
