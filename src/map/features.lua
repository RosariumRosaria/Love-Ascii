local feature_types = require("map.feature_types")
local tile_types = require("map.tile_types")
local entities = require("entities.entities")
local gen_cfg = require("config.generation_config")
local utils = require("utils")

local features = { max_x = nil, max_y = nil }

local rotated_wall = setmetatable({ rotation = 90 }, { __index = tile_types.v_wall })

function features.load(max_x, max_y)
	features.max_x = max_x
	features.max_y = max_y
end

local function in_bounds(x, y)
	if not (features.max_x and features.max_y) then
		error("features.load must run before placing features", 2)
	end
	return utils.in_bounds(x, y, features.max_x, features.max_y)
end

function features.fill_column(tiles, x, y, base_z, top_z, tile)
	for z = base_z, top_z do
		tiles[y][x][z] = tile
	end
end

function features.roll_height(name, max_z)
	local template = feature_types[name]
	if not template then
		return 0
	end
	local base_z = template.base_z or 1
	local height = love.math.random(template.min_height, template.max_height)
	return math.max(0, math.min(height, max_z - base_z + 1))
end

function features.place(name, x, y, tiles, max_z)
	local template = feature_types[name]
	if not template then
		return false
	end

	local base_z = template.base_z or 1
	local height = features.roll_height(name, max_z)
	if height < 1 then
		return false
	end

	local top_z = base_z + height - 1
	local fill = tile_types[template.fill]
	local cap = tile_types[template.cap]

	if fill then
		features.fill_column(tiles, x, y, base_z, cap and top_z - 1 or top_z, fill)
	end
	if cap then
		tiles[y][x][top_z] = cap
	end

	return true
end

function features.make_lake(tiles, cx, cy, radius)
	for dy = -radius, radius do
		for dx = -radius, radius do
			local tx, ty = cx + dx, cy + dy
			if in_bounds(tx, ty) and utils.in_radius(dx, dy, radius) then
				tiles[ty][tx][-1] = tile_types.water
				tiles[ty][tx][1] = tile_types.air
			end
		end
	end

	for bx = cx - radius - 2, cx + radius + 2 do
		if in_bounds(bx, cy) then
			tiles[cy][bx][1] = tile_types.floor
		end
	end
end

function features.make_building(tiles, start_x, start_y, width, height, top_z, road_side)
	for y = 1, height do
		for x = 1, width do
			local tile_x = start_x + x - 1
			local tile_y = start_y + y - 1
			if in_bounds(tile_x, tile_y) then
				if
					(x == 1 and y == 1)
					or (x == width and y == height)
					or (x == 1 and y == height)
					or (x == width and y == 1)
				then
					features.fill_column(tiles, tile_x, tile_y, 1, top_z, tile_types.c_wall)
				elseif x == 1 or x == width then
					features.fill_column(tiles, tile_x, tile_y, 1, top_z, rotated_wall)
				elseif y == 1 or y == height then
					features.fill_column(tiles, tile_x, tile_y, 1, top_z, tile_types.v_wall)
				else
					tiles[tile_y][tile_x][1] = tile_types.floor
				end
			end
		end
	end

	if width <= 2 or height <= 2 then
		return { x = start_x, y = start_y, w = width, h = height }
	end

	local function safe_door_start(len)
		return love.math.random(2, math.max(2, len - 1))
	end

	local door_x = safe_door_start(width)
	local door_y = safe_door_start(height)

	-- Cardinals follow the tile grid: -x is west, +x is east, -y is north, +y is south.
	-- city_generator:nearest_road_side names sides the same way; the two must agree.
	local sides = {
		{ x = start_x, y = start_y + door_y - 1, rotation = 0, weight = 1, cardinal = "west" },
		{
			x = start_x + width - 1,
			y = start_y + door_y - 1,
			rotation = 180,
			weight = 1,
			cardinal = "east",
		},
		{ x = start_x + door_x - 1, y = start_y, rotation = 90, weight = 1, cardinal = "north" },
		{
			x = start_x + door_x - 1,
			y = start_y + height - 1,
			rotation = 270,
			weight = 1,
			cardinal = "south",
		},
	}

	for _, side in ipairs(sides) do
		if side.cardinal == road_side then
			side.weight = gen_cfg.road_side_door_weight
		end
	end

	local door_one = utils.pick_weighted(sides)
	local door_two = nil

	if love.math.random() < gen_cfg.second_door_chance then
		local remaining = {}
		for _, side in ipairs(sides) do
			if side ~= door_one then
				table.insert(remaining, side)
			end
		end
		door_two = utils.pick(remaining)
	end

	for _, side in ipairs(sides) do
		if in_bounds(side.x, side.y) then
			tiles[side.y][side.x][2] = tile_types.air
			if side == door_one or side == door_two then
				tiles[side.y][side.x][1] = tile_types.floor
				entities.add_from_template("door", side.x, side.y, 1, { rotation = side.rotation })
			else
				tiles[side.y][side.x][3] = tile_types.air
				entities.add_from_template("window", side.x, side.y, 1, { rotation = side.rotation })
			end
		end
	end

	return {
		x = start_x,
		y = start_y,
		w = width,
		h = height,
	}
end

function features.scatter(tiles, rect, density, place_fn)
	for y = rect.y, rect.y + rect.h - 1 do
		for x = rect.x, rect.x + rect.w - 1 do
			if in_bounds(x, y) and love.math.random() < density then
				place_fn(x, y)
			end
		end
	end
end

local MAX_SCATTER_ATTEMPTS = 100

function features.scatter_count(tiles, rect, count, place_fn)
	local placed, attempts = 0, 0
	while placed < count and attempts < count * MAX_SCATTER_ATTEMPTS do
		local x = love.math.random(rect.x, rect.x + rect.w - 1)
		local y = love.math.random(rect.y, rect.y + rect.h - 1)
		if in_bounds(x, y) and place_fn(x, y) then
			placed = placed + 1
		end
		attempts = attempts + 1
	end
	return placed
end

return features
