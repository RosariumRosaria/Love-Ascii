local feature_types = require("src.map.feature_types")
local tile_types = require("src.map.tile_types")
local entities = require("src.sim.entities")
local gen_cfg = require("src.config.generation_config")
local utils = require("src.utils")

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

local function touches_corner(mask, x, y, orientation, width, height)
	local dx, dy = 1, 0
	if orientation == "horizontal" then
		dx, dy = 0, 1
	end
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

local function room_pair_key(a, b)
	if a > b then
		a, b = b, a
	end
	return a .. ":" .. b
end

local function add_internal_door(walls, a_id, b_id, x, y, facing, near_corner)
	local key = room_pair_key(a_id, b_id)
	local wall
	for _, existing in ipairs(walls) do
		if existing.key == key then
			wall = existing
			break
		end
	end
	if not wall then
		wall = { key = key, candidates = {} }
		walls[#walls + 1] = wall
	end
	table.insert(wall.candidates, { x = x, y = y, rotation = utils.pick(facing), near_corner = near_corner })
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

local FLOOD_OFFSETS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function report_sealed_rooms(mask, width, height, doors, ox, oy)
	local stride = width + 2
	local open, present = {}, {}
	for _, door in ipairs(doors) do
		open[door.y * stride + door.x] = true
	end

	local start_x, start_y
	for y = 1, height do
		for x = 1, width do
			local id = mask[y][x]
			if id > 0 then
				present[id] = true
				start_x = start_x or x
				start_y = start_y or y
			end
		end
	end
	if not start_x then
		return
	end

	local seen = { [start_y * stride + start_x] = true }
	local reached = { [mask[start_y][start_x]] = true }
	local frontier = { { start_x, start_y } }
	while #frontier > 0 do
		local cell = table.remove(frontier)
		for _, offset in ipairs(FLOOD_OFFSETS) do
			local nx, ny = cell[1] + offset[1], cell[2] + offset[2]
			if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
				local key = ny * stride + nx
				local id = mask[ny][nx]
				if not seen[key] and (id > 0 or open[key]) then
					seen[key] = true
					if id > 0 then
						reached[id] = true
					end
					frontier[#frontier + 1] = { nx, ny }
				end
			end
		end
	end

	local sealed = {}
	for id in pairs(present) do
		if not reached[id] then
			sealed[#sealed + 1] = id
		end
	end
	if #sealed > 0 then
		table.sort(sealed)
		print(
			("features.make_building: %d sealed room(s) [%s] in building at %d,%d"):format(
				#sealed,
				table.concat(sealed, ", "),
				ox + 1,
				oy + 1
			)
		)
	end
end

function features.make_building(tiles, rects, top_z, road_side)
	local bounding_box = get_bounding_box(rects)
	local ox, oy = bounding_box.x - 1, bounding_box.y - 1
	local width, height = bounding_box.w, bounding_box.h
	local mask = make_building_mask(bounding_box, rects)

	local by_cardinal = make_cardinal_buckets()
	local internal_walls = {}

	for y = 1, height do
		for x = 1, width do
			local tile_x = ox + x
			local tile_y = oy + y
			if mask[y][x] ~= 0 and in_bounds(tile_x, tile_y) then
				local orientation = is_boundary(mask, x, y)
				if orientation == "internal" then
					tiles[tile_y][tile_x][1] = tile_types.floor
				elseif orientation == "vertical" then
					features.fill_column(tiles, tile_x, tile_y, 1, top_z, tile_types.v_wall)
					local up_id = mask[y - 1][x]
					local down_id = mask[y + 1][x]
					local near_corner = touches_corner(mask, x, y, orientation, width, height)
					if up_id == 0 and down_id > 0 then
						table.insert(
							by_cardinal.north.candidates,
							{ x = tile_x, y = tile_y, near_corner = near_corner }
						)
					end
					if down_id == 0 and up_id > 0 then
						table.insert(
							by_cardinal.south.candidates,
							{ x = tile_x, y = tile_y, near_corner = near_corner }
						)
					end
					if up_id ~= down_id and up_id > 0 and down_id > 0 then
						add_internal_door(
							internal_walls,
							up_id,
							down_id,
							tile_x,
							tile_y,
							NORTH_SOUTH_FACING,
							near_corner
						)
					end
				elseif orientation == "horizontal" then
					local left_id = mask[y][x - 1]
					local right_id = mask[y][x + 1]
					features.fill_column(tiles, tile_x, tile_y, 1, top_z, rotated_wall)
					local near_corner = touches_corner(mask, x, y, orientation, width, height)
					if left_id == 0 and right_id > 0 then
						table.insert(by_cardinal.west.candidates, { x = tile_x, y = tile_y, near_corner = near_corner })
					end
					if right_id == 0 and left_id > 0 then
						table.insert(by_cardinal.east.candidates, { x = tile_x, y = tile_y, near_corner = near_corner })
					end
					if left_id ~= right_id and left_id > 0 and right_id > 0 then
						add_internal_door(
							internal_walls,
							left_id,
							right_id,
							tile_x,
							tile_y,
							WEST_EAST_FACING,
							near_corner
						)
					end
				elseif orientation == "corner" then
					features.fill_column(tiles, tile_x, tile_y, 1, top_z, tile_types.c_wall)
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

	local doors = {}
	local door_positions = {}

	-- every door is placed before any window, so windows can steer clear of all of them
	for _, side in ipairs(by_cardinal) do
		if side.door then
			local pool = prefer_non_corner(side.candidates)
			local pos = #pool > 0 and utils.pick(pool) or nil
			if pos and in_bounds(pos.x, pos.y) then
				stamp_door(pos.x, pos.y, side.rotation, tiles)
				doors[#doors + 1] = { x = pos.x - ox, y = pos.y - oy }
				door_positions[#door_positions + 1] = pos
				utils.remove_from_list(side.candidates, pos)
			end
		end
	end

	for _, wall in ipairs(internal_walls) do
		local pos = utils.pick(prefer_non_corner(wall.candidates))
		if love.math.random() < gen_cfg.doors.open_internal_chance then
			stamp_door(pos.x, pos.y, pos.rotation, tiles)
		else
			tiles[pos.y][pos.x][2] = tile_types.air
			tiles[pos.y][pos.x][1] = tile_types.floor
		end
		doors[#doors + 1] = { x = pos.x - ox, y = pos.y - oy }
		door_positions[#door_positions + 1] = pos
	end

	for _, side in ipairs(by_cardinal) do
		local window_count = side.door and 1 or 2
		for _ = 1, window_count do
			local pool = prefer_away_from_doors(side.candidates, door_positions)
			local pos = #pool > 0 and utils.pick(pool) or nil
			if pos and in_bounds(pos.x, pos.y) then
				stamp_window(pos.x, pos.y, side.rotation, tiles)
			end
			if pos then
				utils.remove_from_list(side.candidates, pos)
			end
		end
	end

	report_sealed_rooms(mask, width, height, doors, ox, oy)

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
