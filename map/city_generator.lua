local entities = require("entities.entities")
local types = require("map.tile_types")
local utils = require("utils")
local gen_cfg = require("config.generation_config")
local lots = require("map.lots")
local structures = require("map.structures")
local city_generator = { max_x = nil, max_y = nil, max_z = nil, lots = {}, roads = {} }

local rotated_wall = setmetatable({ rotation = 90 }, { __index = types.v_wall })

function city_generator:get_lots()
	return self.lots
end

function city_generator:get_roads()
	return self.roads
end

function city_generator:make_lake(cx, cy, radius, tiles)
	for dy = -radius, radius do
		for dx = -radius, radius do
			local tx, ty = cx + dx, cy + dy
			if utils.in_bounds(tx, ty, self.max_x, self.max_y) and utils.in_radius(dx, dy, radius) then
				tiles[ty][tx][-1] = types.water
				tiles[ty][tx][1] = types.air
			end
		end
	end

	for bx = cx - radius - 2, cx + radius + 2 do
		if utils.in_bounds(bx, cy, self.max_x, self.max_y) then
			tiles[cy][bx][1] = types.floor
		end
	end
end

function city_generator:make_copse(cx, cy, radius, density, tiles)
	for dy = -radius, radius do
		for dx = -radius, radius do
			if dx * dx + dy * dy <= radius * radius and math.random() < density then
				local tile_x, tile_y = cx + dx, cy + dy
				if utils.in_bounds(tile_x, tile_y, self.max_x, self.max_y) then
					structures.place("tree", tile_x, tile_y, tiles, self.max_z)
				end
			end
		end
	end
end

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
					structures.fill_column(tiles, tile_x, tile_y, 1, max_z, types.c_wall)
				elseif x == 1 or x == width then
					structures.fill_column(tiles, tile_x, tile_y, 1, max_z, rotated_wall)
				elseif y == 1 or y == height then
					structures.fill_column(tiles, tile_x, tile_y, 1, max_z, types.v_wall)
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
				entities.add_from_template("door", side.x, side.y, 1, { rotation = side.rotation })
			else
				tiles[side.y][side.x][3] = types.air
				entities.add_from_template("window", side.x, side.y, 1, { rotation = side.rotation })
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
function city_generator:load(tiles, map_max_y, map_max_x, map_max_z, map_min_z)
	self.max_y = map_max_y
	self.max_x = map_max_x
	self.max_z = map_max_z
	self.min_z = map_min_z
	self.lots = {}
	self.roads = {}
	local root = { x = 1, y = 1, w = self.max_x, h = self.max_y }
	lots.subdivide(root, gen_cfg.subdivide_depth, self.lots, self.roads)

	for y = 1, map_max_y do
		for x = 1, map_max_x do
			tiles[y][x][1] = types.grass
			if math.random(1, gen_cfg.shrub_chance) == gen_cfg.shrub_chance then
				tiles[y][x][1] = types.shrub
			end
		end
	end
	for _, road in ipairs(self.roads) do
		for y = road.y, road.y + road.h - 1 do
			for x = road.x, road.x + road.w - 1 do
				tiles[y][x][1] = types.road
			end
		end
	end

	for _, lot in ipairs(self.lots) do
		local m = math.random(1, gen_cfg.building_margin)
		local bw, bh = lot.w - 2 * m, lot.h - 2 * m
		if bw >= gen_cfg.min_building_size and bh >= gen_cfg.min_building_size then
			local roll = math.random()
			if roll < gen_cfg.building_chance then
				self:make_building(lot.x + m, lot.y + m, bw, bh, structures.roll_height("wall", self.max_z), tiles)
			elseif roll < gen_cfg.building_chance + gen_cfg.copse_chance then
				local cx = lot.x + m + math.floor(bw / 2)
				local cy = lot.y + m + math.floor(bh / 2)
				local radius = math.floor(math.min(bw, bh) / 2)
				local variance = gen_cfg.copse_density_variance
				local tree_density_adjusted = gen_cfg.copse_density - variance + (variance * math.random())
				self:make_copse(cx, cy, radius, tree_density_adjusted, tiles)
			end
		end
	end
end

return city_generator
