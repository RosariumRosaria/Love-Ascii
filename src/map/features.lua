local feature_types = require("src.map.feature_types")
local tile_types = require("src.map.tile_types")
local entities = require("src.sim.entities")
local generation_report = require("src.debug.generation_report")
local gen_cfg = require("src.config.generation_config")
local utils = require("src.utils")

local features = { max_x = nil, max_y = nil }

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

local function make_building_mask(bounding_box, rects)
	local mask = {}
	for y = 0, bounding_box.h + 1 do
		mask[y] = {}
		for x = 0, bounding_box.w + 1 do
			mask[y][x] = 0
		end
	end
	for _, rect in ipairs(rects) do
		local rx, ry = rect.x - bounding_box.x, rect.y - bounding_box.y
		for y = ry + 1, ry + rect.h do
			for x = rx + 1, rx + rect.w do
				mask[y][x] = -1
			end
		end
	end

	for i, rect in ipairs(rects) do
		local rx, ry = rect.x - bounding_box.x, rect.y - bounding_box.y
		for y = ry + 2, ry + rect.h - 1 do
			for x = rx + 2, rx + rect.w - 1 do
				mask[y][x] = i
			end
		end
	end

	return mask
end

local function check_neighbor(grid, x, y, id)
	return grid[y][x] == id
end

local function is_boundary(region, x, y)
	local id = region[y][x]

	if id ~= -1 then
		return "internal"
	end

	local vertical = check_neighbor(region, x - 1, y, id) or check_neighbor(region, x + 1, y, id)
	local horizontal = check_neighbor(region, x, y - 1, id) or check_neighbor(region, x, y + 1, id)
	local orientation = "internal"

	if horizontal and vertical then
		orientation = "corner"
	elseif horizontal then
		orientation = "horizontal"
	elseif vertical then
		orientation = "vertical"
	end

	return orientation
end

local function is_corner_cell(mask, x, y, width, height)
	if x < 1 or x > width or y < 1 or y > height then
		return false
	end
	return is_boundary(mask, x, y) == "corner"
end

local function touches_corner(mask, x, y, axis, width, height)
	local dx, dy = axis.along_x, axis.along_y
	return is_corner_cell(mask, x - dx, y - dy, width, height) or is_corner_cell(mask, x + dx, y + dy, width, height)
end

local function prefer_non_corner(candidates)
	local filtered = {}
	for _, candidate in ipairs(candidates) do
		if not candidate.near_corner then
			filtered[#filtered + 1] = candidate
		end
	end
	return #filtered > 0 and filtered or candidates
end

local function prefer_away_from_doors(candidates, door_positions)
	if #door_positions == 0 then
		return candidates
	end

	local gap = gen_cfg.windows.door_gap
	local filtered = {}
	for _, candidate in ipairs(candidates) do
		local clear = true
		for _, door in ipairs(door_positions) do
			if math.abs(candidate.x - door.x) <= gap and math.abs(candidate.y - door.y) <= gap then
				clear = false
				break
			end
		end
		if clear then
			filtered[#filtered + 1] = candidate
		end
	end
	return #filtered > 0 and filtered or candidates
end

local function get_bounding_box(rects)
	local min_x, min_y, max_x, max_y
	for _, rect in ipairs(rects) do
		if not min_x or min_x > rect.x then
			min_x = rect.x
		end
		if not min_y or min_y > rect.y then
			min_y = rect.y
		end
		if not max_x or max_x < rect.x + rect.w then
			max_x = rect.x + rect.w
		end
		if not max_y or max_y < rect.y + rect.h then
			max_y = rect.y + rect.h
		end
	end

	return { x = min_x, y = min_y, w = max_x - min_x, h = max_y - min_y }
end

local function stamp_door(x, y, rotation, tiles)
	tiles[y][x][2] = tile_types.air
	tiles[y][x][1] = tile_types.floor
	entities.add_from_template("door", x, y, 1, { rotation = rotation })
end

local function stamp_window(x, y, rotation, tiles)
	tiles[y][x][2] = tile_types.air
	tiles[y][x][3] = tile_types.air
	entities.add_from_template("window", x, y, 1, { rotation = rotation })
end

local NORTH_SOUTH_FACING = { 90, 270 }
local WEST_EAST_FACING = { 0, 180 }

local WALL_SETS = {
	timber = { vertical = tile_types.v_wall, horizontal = tile_types.h_wall, corner = tile_types.c_wall },
	stone = { vertical = tile_types.v_stone_wall, horizontal = tile_types.h_stone_wall, corner = tile_types.c_wall },
}

local WALL_AXES = {
	vertical = {
		along_x = 1,
		along_y = 0,
		across_x = 0,
		across_y = 1,
		low = "north",
		high = "south",
		facing = NORTH_SOUTH_FACING,
	},
	horizontal = {
		along_x = 0,
		along_y = 1,
		across_x = 1,
		across_y = 0,
		low = "west",
		high = "east",
		facing = WEST_EAST_FACING,
	},
}

local function room_pair_key(a, b)
	if a > b then
		a, b = b, a
	end
	return a .. ":" .. b
end

local function add_candidate(candidates, x, y, rotation, near_corner)
	candidates[#candidates + 1] = { x = x, y = y, rotation = rotation, near_corner = near_corner }
end

local function add_room_adjacency(walls, a_id, b_id, x, y, facing, near_corner)
	local key = room_pair_key(a_id, b_id)
	local wall
	for _, existing in ipairs(walls) do
		if existing.key == key then
			wall = existing
			break
		end
	end
	if not wall then
		wall = { key = key, candidates = {}, a_id = a_id, b_id = b_id }
		walls[#walls + 1] = wall
	end
	add_candidate(wall.candidates, x, y, utils.pick(facing), near_corner)
end

local function find(parent, id)
	parent[id] = parent[id] or id
	while parent[id] ~= id do
		parent[id] = parent[parent[id]]
		id = parent[id]
	end
	return id
end

local function try_edge(parent, wall, kept, rejects)
	local ra, rb = find(parent, wall.a_id), find(parent, wall.b_id)
	if ra ~= rb then
		parent[ra] = rb
		table.insert(kept, wall)
	else
		table.insert(rejects, wall)
	end
end

local function choose_openings(walls, rooms)
	local kept = {}
	local parent = {}
	local rejects = {}
	local biggest = nil
	local biggest_id = nil
	for i, room in ipairs(rooms) do
		if not biggest or (room.w - 2) * (room.h - 2) > (biggest.w - 2) * (biggest.h - 2) then
			biggest = room
			biggest_id = i
		end
	end
	utils.shuffle(walls)
	local near, far = {}, {}
	for _, w in ipairs(walls) do
		local t = (w.a_id == biggest_id or w.b_id == biggest_id) and near or far
		t[#t + 1] = w
	end
	for _, wall in ipairs(near) do
		try_edge(parent, wall, kept, rejects)
	end
	for _, wall in ipairs(far) do
		try_edge(parent, wall, kept, rejects)
	end

	local loop_count = love.math.random(gen_cfg.doors.min_loops, gen_cfg.doors.max_loops)
	for _ = 1, loop_count do
		if #rejects > 0 then
			local wall = utils.pick(rejects)
			table.insert(kept, wall)
			utils.remove_from_list(rejects, wall)
		end
	end

	return kept
end

-- kind of hacky but I wanted to reuse some of my utils that needed pairs
local function make_cardinal_buckets()
	local west = { rotation = 0, weight = 1, cardinal = "west", candidates = {} }
	local east = { rotation = 180, weight = 1, cardinal = "east", candidates = {} }
	local north = { rotation = 90, weight = 1, cardinal = "north", candidates = {} }
	local south = { rotation = 270, weight = 1, cardinal = "south", candidates = {} }

	return {
		west,
		east,
		north,
		south,
		west = west,
		east = east,
		north = north,
		south = south,
	}
end

function features.make_building(tiles, rects, top_z, road_side, lighting_grid, material)
	local bounding_box = get_bounding_box(rects)
	local ox, oy = bounding_box.x - 1, bounding_box.y - 1
	local width, height = bounding_box.w, bounding_box.h
	local mask = make_building_mask(bounding_box, rects)
	material = material or "timber"
	local by_cardinal = make_cardinal_buckets()
	local internal_walls = {}

	for y = 1, height do
		for x = 1, width do
			local tile_x = ox + x
			local tile_y = oy + y
			if mask[y][x] ~= 0 and in_bounds(tile_x, tile_y) then
				local orientation = is_boundary(mask, x, y)
				local axis = WALL_AXES[orientation]
				local tile = WALL_SETS[material][orientation]
				if orientation == "internal" then
					tiles[tile_y][tile_x][1] = tile_types.floor
					lighting_grid[tile_y][tile_x].sky = 0
				elseif orientation == "corner" then
					features.fill_column(tiles, tile_x, tile_y, 1, top_z, tile)
				elseif axis then
					features.fill_column(tiles, tile_x, tile_y, 1, top_z, tile)
					local low_id = mask[y - axis.across_y][x - axis.across_x]
					local high_id = mask[y + axis.across_y][x + axis.across_x]
					local near_corner = touches_corner(mask, x, y, axis, width, height)
					local low, high = by_cardinal[axis.low], by_cardinal[axis.high]
					if low_id == 0 and high_id > 0 then
						add_candidate(low.candidates, tile_x, tile_y, low.rotation, near_corner)
					end
					if high_id == 0 and low_id > 0 then
						add_candidate(high.candidates, tile_x, tile_y, high.rotation, near_corner)
					end
					if low_id ~= high_id and low_id > 0 and high_id > 0 then
						add_room_adjacency(internal_walls, low_id, high_id, tile_x, tile_y, axis.facing, near_corner)
					end
				end
			end
		end
	end
	if width <= 2 or height <= 2 then
		return bounding_box, rects
	end

	if road_side and by_cardinal[road_side] then
		by_cardinal[road_side].weight = gen_cfg.doors.road_side_weight
	end

	utils.pick_weighted(by_cardinal).door = true

	if love.math.random() < gen_cfg.doors.second_chance then
		local remaining = {}
		for _, side in ipairs(by_cardinal) do
			if not side.door then
				table.insert(remaining, side)
			end
		end
		utils.pick(remaining).door = true
	end

	local doorways = {}

	for _, side in ipairs(by_cardinal) do
		if side.door then
			local pool = prefer_non_corner(side.candidates)
			local pos = #pool > 0 and utils.pick(pool) or nil
			if pos and in_bounds(pos.x, pos.y) then
				stamp_door(pos.x, pos.y, pos.rotation, tiles)
				doorways[#doorways + 1] = pos
				utils.remove_from_list(side.candidates, pos)
			end
		end
	end

	local open_walls = choose_openings(internal_walls, rects)

	for _, wall in ipairs(open_walls) do
		local pos = utils.pick(prefer_non_corner(wall.candidates))
		lighting_grid[pos.y][pos.x].sky = 0
		if love.math.random() < gen_cfg.doors.open_internal_chance then
			stamp_door(pos.x, pos.y, pos.rotation, tiles)
		else
			tiles[pos.y][pos.x][2] = tile_types.air
			tiles[pos.y][pos.x][1] = tile_types.floor
		end
		doorways[#doorways + 1] = pos
	end

	for _, side in ipairs(by_cardinal) do
		local window_count = side.door and 1 or 2
		for _ = 1, window_count do
			local pool = prefer_away_from_doors(side.candidates, doorways)
			local pos = #pool > 0 and utils.pick(pool) or nil
			if pos then
				if in_bounds(pos.x, pos.y) then
					stamp_window(pos.x, pos.y, pos.rotation, tiles)
				end
				utils.remove_from_list(side.candidates, pos)
			end
		end
	end

	generation_report.check_sealed_rooms(mask, width, height, doorways, ox, oy)

	return bounding_box, rects
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
