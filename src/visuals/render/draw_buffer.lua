local render_primitives = require("src.visuals.render.primitives")
local config = require("src.config.runtime")
local game_cfg = require("src.config.game_config")
local debug_state = require("src.debug.debug_state")

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

-- Per-frame emit stats, published to perf by scene:draw. rect/char counts are plain
-- increments; the churn counters cost a table read per emit, so they only run while the
-- perf overlay is up (latched once per frame in :clear).
local rect_count = 0
local char_count = 0
local kind_flips = 0
local new_entries = 0
local track_churn = false

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
		-- Born holding the union of every field both kinds write. Entries are recycled
		-- across kinds, so a table that starts empty grows its hash part a key at a time
		-- and re-grows it whenever a slot flips rect <-> char -- each miss is an
		-- lj_tab_newkey plus a rehash, in the hottest loop in the frame. Sized once here,
		-- no store after this is ever a new key. Values are placeholders; acquire is
		-- always followed by a full assignment for the kind being emitted.
		d = {
			kind = false,
			x_screen = 0,
			y_screen = 0,
			r = 1,
			g = 1,
			b = 1,
			a = 1,
			outline_color = false,
			char = false,
			rotation = false,
			natural_rotation = false,
			size_scale = false,
			mirror_facing = false,
			w = 0,
			h = 0,
			outline_width = false,
			rounded_amount = false,
		}
		buf[n] = d
		if track_churn then
			new_entries = new_entries + 1
		end
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
	char_count = char_count + 1
	if track_churn and d.kind ~= "char" then
		kind_flips = kind_flips + 1
	end
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
	rect_count = rect_count + 1
	if track_churn and d.kind ~= "rect" then
		kind_flips = kind_flips + 1
	end
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

	track_churn = debug_state.show_perf
	rect_count = 0
	char_count = 0
	kind_flips = 0
	new_entries = 0
end

-- entries, rects, chars, slots that changed kind this frame, tables allocated this frame.
-- The churn figures read 0 unless the perf overlay was up when :clear ran.
function draw_buffer:get_stats()
	return count, rect_count, char_count, kind_flips, new_entries
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
