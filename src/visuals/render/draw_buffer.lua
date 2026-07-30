local render_primitives = require("src.visuals.render.primitives")
local config = require("src.config.runtime")
local game_cfg = require("src.config.game_config")

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
local count = 0

local buckets = {}
local bucket_counts = {}
local occupied = {}
local occupied_count = 0

local Z_MIN = game_cfg.map.min_z
local Z_SLOTS = 4096
local LAYER_SLOTS = 16
local Y_MIN = -2
local Y_SLOTS = 2 ^ 18
local ORDER_W = 2 ^ 17
assert(Y_SLOTS * ORDER_W <= 2 ^ 53, "draw_buffer: packed sort key exceeds double precision")

local floor = math.floor
local sort = table.sort

local function acquire(pass, z, y, layer)
	local n = count + 1
	if n >= ORDER_W then
		error("draw_buffer: exceeded " .. (ORDER_W - 1) .. " entries in one frame")
	end
	count = n

	local d = buf[n]
	if not d then
		d = {}
		buf[n] = d
	end

	local zq = floor((z - Z_MIN) * 64)
	if zq < 0 then
		zq = 0
	elseif zq >= Z_SLOTS then
		zq = Z_SLOTS - 1
	end
	local yq = floor((y - Y_MIN) * 256)
	if yq < 0 then
		yq = 0
	elseif yq >= Y_SLOTS then
		yq = Y_SLOTS - 1
	end

	local bucket_index = (((pass or 0) * Z_SLOTS + zq) * LAYER_SLOTS) + layer
	local bucket = buckets[bucket_index]
	if not bucket then
		bucket = {}
		buckets[bucket_index] = bucket
	end
	-- A live bucket always holds at least one entry, so a count of 0 (or nil)
	-- means this is the first emit into it this frame.
	local bucket_count = bucket_counts[bucket_index]
	if not bucket_count or bucket_count == 0 then
		bucket_count = 0
		occupied_count = occupied_count + 1
		occupied[occupied_count] = bucket_index
	end
	bucket_count = bucket_count + 1
	bucket_counts[bucket_index] = bucket_count
	bucket[bucket_count] = yq * ORDER_W + n

	return d
end

function draw_buffer:emit_char(
	pass,
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
	outline_color,
	rotation,
	natural_rotation,
	size_scale,
	mirror_facing
)
	local d = acquire(pass, z, y, layer)
	d.kind = "char"
	d.x_screen = x_screen
	d.y_screen = y_screen
	d.char = char
	d.r = r
	d.g = g
	d.b = b
	d.a = a
	d.outline_color = outline_color
	d.rotation = rotation
	d.natural_rotation = natural_rotation
	d.size_scale = size_scale
	d.mirror_facing = mirror_facing
end

function draw_buffer:emit_rect(
	pass,
	z,
	y,
	layer,
	x_screen,
	y_screen,
	w,
	h,
	r,
	g,
	b,
	a,
	outline_width,
	outline_color,
	rounded_amount
)
	local d = acquire(pass, z, y, layer)
	d.kind = "rect"
	d.x_screen = x_screen
	d.y_screen = y_screen
	d.w = w
	d.h = h
	d.r = r
	d.g = g
	d.b = b
	d.a = a
	d.outline_width = outline_width
	d.outline_color = outline_color
	d.rounded_amount = rounded_amount
end

function draw_buffer:clear()
	for i = 1, occupied_count do
		bucket_counts[occupied[i]] = 0
	end
	occupied_count = 0
	count = 0
end

function draw_buffer:sort()
	for i = #occupied, occupied_count + 1, -1 do
		occupied[i] = nil
	end
	sort(occupied)

	for i = 1, occupied_count do
		local bucket_index = occupied[i]
		local bucket = buckets[bucket_index]
		local bucket_count = bucket_counts[bucket_index]
		-- Buckets are reused across frames, so drop any tail left by a bigger frame
		-- before sorting -- table.sort works off #bucket.
		for j = #bucket, bucket_count + 1, -1 do
			bucket[j] = nil
		end
		-- Emission order is usually already correct; only pay for a sort when it isn't.
		local sorted = true
		for j = 2, bucket_count do
			if bucket[j] < bucket[j - 1] then
				sorted = false
				break
			end
		end
		if not sorted then
			sort(bucket)
		end
	end
end

local function dispatch(d)
	if d.kind == "char" then
		render_primitives.draw_char(
			d.x_screen,
			d.y_screen,
			d.char,
			d.r,
			d.g,
			d.b,
			d.a,
			d.outline_color,
			d.rotation,
			d.natural_rotation,
			d.size_scale,
			d.mirror_facing
		)
	else
		render_primitives.draw_rect_rgba(
			d.x_screen,
			d.y_screen,
			d.w,
			d.h,
			d.r,
			d.g,
			d.b,
			d.a,
			d.outline_width,
			d.outline_color,
			d.rounded_amount
		)
	end
end

function draw_buffer:walk()
	love.graphics.setFont(config.font)

	for i = 1, occupied_count do
		local bucket_index = occupied[i]
		local bucket = buckets[bucket_index]
		for j = 1, bucket_counts[bucket_index] do
			dispatch(buf[bucket[j] % ORDER_W])
		end
	end
end

return draw_buffer
