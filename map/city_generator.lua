local entities = require("entities.entities")
local types = require("map.tile_types")
local utils = require("utils")
local gen_cfg = require("config.generation_config")
local city_generator = { max_x = nil, max_y = nil, max_z = nil }

function city_generator:make_building(room_start_x, room_start_y, width, height, max_z, tiles)
	for y = 1, height do
		for x = 1, width do
			local tile_x = room_start_x + x - 1
			local tile_y = room_start_y + y - 1
			if utils.in_bounds(tile_x, tile_y, self.max_x, self.max_y) then
				if
					(x == 1 and y == 1)
					or (x == width and y == height)
					or (x == 1 and y == height)
					or (x == width and y == 1)
				then
					for z = 1, max_z do
						tiles[tile_y][tile_x][z] = types.c_wall
					end
				elseif x == 1 or x == width then
					for z = 1, max_z do
						tiles[tile_y][tile_x][z] = types.h_wall
					end
				elseif y == 1 or y == height then
					for z = 1, max_z do
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
		if utils.in_bounds(side.x, side.y, self.max_x, self.max_y) then
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

function city_generator:make_town(room_count, tiles, map_max_y, map_max_x, map_max_z, map_min_z)
	self.max_y = map_max_y
	self.max_x = map_max_x
	self.max_z = map_max_z
	self.min_z = map_min_z
	for y = 1, map_max_y do
		for x = 1, map_max_x do
			tiles[y][x][1] = types.grass
			if math.random(1, gen_cfg.shrub_chance) == gen_cfg.shrub_chance then
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

			local x = math.random(gen_cfg.building_margin, map_max_x - gen_cfg.building_margin * 2)
			local y = math.random(gen_cfg.building_margin, map_max_y - gen_cfg.building_margin * 2)
			local w = math.random(gen_cfg.building_min_size, gen_cfg.building_max_size)
			local h = math.random(gen_cfg.building_min_size, gen_cfg.building_max_size)
			potential_building = { x = x, y = y, width = w, height = h }

			for _, other in ipairs(buildings) do
				if utils.overlapping_rectangles(potential_building, other) then
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
			math.random(3, map_max_z),
			tiles
		)
	end
end

return city_generator
