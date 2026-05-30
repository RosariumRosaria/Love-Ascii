local structure_types = require("map.structure_types")
local tile_types = require("map.tile_types")
local entities = require("entities.entities")
local utils = require("utils")

local structures = {}

local rotated_wall = setmetatable({ rotation = 90 }, { __index = tile_types.v_wall })

function structures.fill_column(tiles, x, y, base_z, top_z, tile)
	for z = base_z, top_z do
		tiles[y][x][z] = tile
	end
end

function structures.roll_height(name, max_z)
	local template = structure_types[name]
	if not template then
		return 0
	end
	local base_z = template.base_z or 1
	local height = math.random(template.min_height, template.max_height)
	return math.max(0, math.min(height, max_z - base_z + 1))
end

function structures.place(name, x, y, tiles, max_z)
	local template = structure_types[name]
	if not template then
		return
	end

	local base_z = template.base_z or 1
	local height = structures.roll_height(name, max_z)
	if height < 1 then
		return
	end

	local top_z = base_z + height - 1
	local fill = tile_types[template.fill]
	local cap = tile_types[template.cap]

	if fill then
		structures.fill_column(tiles, x, y, base_z, cap and top_z - 1 or top_z, fill)
	end
	if cap then
		tiles[y][x][top_z] = cap
	end
end

function structures.make_lake(tiles, cx, cy, radius, max_x, max_y)
	for dy = -radius, radius do
		for dx = -radius, radius do
			local tx, ty = cx + dx, cy + dy
			if utils.in_bounds(tx, ty, max_x, max_y) and utils.in_radius(dx, dy, radius) then
				tiles[ty][tx][-1] = tile_types.water
				tiles[ty][tx][1] = tile_types.air
			end
		end
	end

	for bx = cx - radius - 2, cx + radius + 2 do
		if utils.in_bounds(bx, cy, max_x, max_y) then
			tiles[cy][bx][1] = tile_types.floor
		end
	end
end

function structures.make_copse(tiles, cx, cy, radius, density, max_x, max_y, max_z)
	for dy = -radius, radius do
		for dx = -radius, radius do
			if dx * dx + dy * dy <= radius * radius and math.random() < density then
				local tile_x, tile_y = cx + dx, cy + dy
				if utils.in_bounds(tile_x, tile_y, max_x, max_y) then
					structures.place("tree", tile_x, tile_y, tiles, max_z)
				end
			end
		end
	end
end

function structures.make_building(tiles, start_x, start_y, width, height, top_z, max_x, max_y)
	for y = 1, height do
		for x = 1, width do
			local tile_x = start_x + x - 1
			local tile_y = start_y + y - 1
			if utils.in_bounds(tile_x, tile_y, max_x, max_y) then
				if
					(x == 1 and y == 1)
					or (x == width and y == height)
					or (x == 1 and y == height)
					or (x == width and y == 1)
				then
					structures.fill_column(tiles, tile_x, tile_y, 1, top_z, tile_types.c_wall)
				elseif x == 1 or x == width then
					structures.fill_column(tiles, tile_x, tile_y, 1, top_z, rotated_wall)
				elseif y == 1 or y == height then
					structures.fill_column(tiles, tile_x, tile_y, 1, top_z, tile_types.v_wall)
				else
					tiles[tile_y][tile_x][1] = tile_types.floor
				end
			end
		end
	end

	if width <= 2 or height <= 2 then
		return { x = start_x, y = start_y, width = width, height = height }
	end

	local function safe_door_start(len)
		return math.random(2, math.max(2, len - 1))
	end

	local door_x = safe_door_start(width)
	local door_y = safe_door_start(height)

	local sides = {
		{ x = start_x, y = start_y + door_y - 1, rotation = 0 },
		{ x = start_x + width - 1, y = start_y + door_y - 1, rotation = 180 },
		{ x = start_x + door_x - 1, y = start_y, rotation = 90 },
		{ x = start_x + door_x - 1, y = start_y + height - 1, rotation = 270 },
	}

	local dir = math.random(1, 4)
	local dir2 = math.random(1, 4)

	for i, side in ipairs(sides) do
		if utils.in_bounds(side.x, side.y, max_x, max_y) then
			tiles[side.y][side.x][2] = tile_types.air
			if dir == i or dir2 == i then
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
		width = width,
		height = height,
	}
end

return structures
