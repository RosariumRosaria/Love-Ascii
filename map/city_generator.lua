local entities = require("entities.entities")
local types = require("map.tile_types")
local city_generator = { width = nil, height = nil, depth = nil }

local function in_bounds(x, y, width, height) -- Can maybe moved to separate file
	return x >= 1 and x <= width and y >= 1 and y <= height
end

local function overlapping_rectangles(r1, r2) -- Can maybe moved to separate file
	return not (
		r1.x + r1.width <= r2.x
		or r2.x + r2.width <= r1.x
		or r1.y + r1.height <= r2.y
		or r2.y + r2.height <= r1.y
	)
end

function city_generator:make_building(room_start_x, room_start_y, width, height, depth, tiles)
	for y = 1, height do
		for x = 1, width do
			local tile_x = room_start_x + x - 1
			local tile_y = room_start_y + y - 1
			if in_bounds(tile_x, tile_y, self.width, self.height) then
				if
					(x == 1 and y == 1)
					or (x == width and y == height)
					or (x == 1 and y == height)
					or (x == width and y == 1)
				then
					for z = 1, depth do
						tiles[tile_y][tile_x][z] = types.c_wall
					end
				elseif x == 1 or x == width then
					for z = 1, depth do
						tiles[tile_y][tile_x][z] = types.h_wall
					end
				elseif y == 1 or y == height then
					for z = 1, depth do
						tiles[tile_y][tile_x][z] = types.v_wall
					end
				else
					tiles[tile_y][tile_x][1] = types.floor
				end
			end
		end
	end

	if width <= 2 or height <= 2 then
		return { x = room_start_x, y = room_start_y, width = width, height = height }
	end

	local function safe_door_start(len)
		return math.random(2, math.max(2, len - 1))
	end

	local door_x = safe_door_start(width)
	local door_y = safe_door_start(height)

	local sides = {
		{ x = room_start_x, y = room_start_y + door_y - 1, rotation = 0 },
		{ x = room_start_x + width - 1, y = room_start_y + door_y - 1, rotation = 180 },
		{ x = room_start_x + door_x - 1, y = room_start_y, rotation = 90 },
		{ x = room_start_x + door_x - 1, y = room_start_y + height - 1, rotation = 270 },
	}

	local dir = math.random(1, 4)
	local dir2 = math.random(1, 4)

	for i, side in ipairs(sides) do
		if in_bounds(side.x, side.y, self.width, self.height) then
			tiles[side.y][side.x][2] = types.air
			if dir == i or dir2 == i then
				tiles[side.y][side.x][1] = types.floor
				entities:add_from_template("door", side.x, side.y, 1, { rotation = side.rotation })
			else
				tiles[side.y][side.x][3] = types.air
				entities:add_from_template("window", side.x, side.y, 1, { rotation = side.rotation })
			end
		end
	end

	return {
		x = room_start_x,
		y = room_start_y,
		width = width,
		height = height,
	}
end

function city_generator:make_town(room_count, tiles, map_height, map_width, map_depth)
	self.height = map_height
	self.width = map_width
	self.depth = map_depth
	for y = 1, map_height do
		for x = 1, map_width do
			tiles[y][x][1] = types.grass
			if math.random(1, 15) == 15 then
				tiles[y][x][1] = types.shrub
			end
		end
	end

	local buildings = {}

	for _ = 1, room_count do
		local potential_building
		local overlaps = true

		while overlaps do --TODO can techincal break w/ dense maps
			overlaps = false

			local x = math.random(10, map_width - 20) --TODO make fix magic numbers
			local y = math.random(10, map_height - 20)
			local w = math.random(5, 15)
			local h = math.random(5, 15)
			potential_building = { x = x, y = y, width = w, height = h }

			for _, other in ipairs(buildings) do
				if overlapping_rectangles(potential_building, other) then
					overlaps = true
					break
				end
			end
		end

		table.insert(buildings, potential_building)
		self:make_building(
			potential_building.x,
			potential_building.y,
			potential_building.width,
			potential_building.height,
			math.random(3, map_depth),
			tiles
		)
	end
end

return city_generator
