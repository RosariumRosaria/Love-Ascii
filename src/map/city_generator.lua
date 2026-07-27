local types = require("src.map.tile_types")
local gen_cfg = require("src.config.generation_config")
local lots = require("src.map.lots")
local features = require("src.map.features")
local entities = require("src.sim.entities")
local utils = require("src.utils")
local city_generator = { max_x = nil, max_y = nil, max_z = nil, lots = {}, roads = {}, buildings = {}, distance = {} }

function city_generator:get_dist()
	return self.distance
end

function city_generator:get_lots()
	return self.lots
end

function city_generator:get_roads()
	return self.roads
end

function city_generator:get_buildings()
	return self.buildings
end

local function point_to_rect(px, py, rect)
	local dx = math.max(rect.x - px, 0, px - (rect.x + rect.w - 1))
	local dy = math.max(rect.y - py, 0, py - (rect.y + rect.h - 1))
	return dx + dy
end

local function nearest_rect_dist(px, py, rects)
	local dist = math.huge
	for _, rect in ipairs(rects) do
		dist = math.min(dist, point_to_rect(px, py, rect))
	end
	return dist
end

function city_generator:distance_to_road(x, y)
	return nearest_rect_dist(x, y, self.roads)
end

function city_generator:nearest_road_side(rect)
	local cx = rect.x + math.floor(rect.w / 2)
	local cy = rect.y + math.floor(rect.h / 2)
	local sides = {
		{ name = "north", x = cx, y = rect.y },
		{ name = "south", x = cx, y = rect.y + rect.h - 1 },
		{ name = "west", x = rect.x, y = cy },
		{ name = "east", x = rect.x + rect.w - 1, y = cy },
	}

	if #self.roads == 0 then
		return nil
	end

	local best_dist, tied = math.huge, {}
	for _, side in ipairs(sides) do
		local dist = self:distance_to_road(side.x, side.y)

		if dist < best_dist then
			best_dist, tied = dist, { side.name }
		elseif dist == best_dist then
			table.insert(tied, side.name)
		end
	end

	return utils.pick(tied)
end

local SHRUBS = { types.shrub, types.short_shrub, types.tall_shrub } --TODO someday I'd like a system to be able to jitter color and natural height, but being considerate for perf
function city_generator:wild(start_x, start_y, end_x, end_y, tiles, root)
	local map = require("src.map.map")
	for y = start_y, end_y do
		for x = start_x, end_x do
			if tiles[y][x][1] == types.grass then
				local noise = love.math.noise(x * gen_cfg.scale + self.noise_ox, y * gen_cfg.scale + self.noise_oy)
				local n = self.distance[y][x] + (noise - 0.5) * gen_cfg.noise_strength
				local v = n + ((love.math.random() - 0.5) * gen_cfg.jitter)
				local tree_strength = ((v - gen_cfg.tree_threshold) / gen_cfg.tree_ramp) * gen_cfg.canopy_density
				local shrub_strength = (v - gen_cfg.shrub_threshold) / gen_cfg.shrub_ramp
				if love.math.random() < tree_strength and map:is_tile_free(x, y, 1) then
					features.place("tree", x, y, tiles, self.max_z)
				elseif love.math.random() < shrub_strength then
					local t = math.ceil(utils.clamp(shrub_strength, 0, 1) * #SHRUBS)
					local shrub_type = SHRUBS[t]
					tiles[y][x][1] = shrub_type
				end
			end
		end
	end
	features.scatter(tiles, root, gen_cfg.shrub_chance, function(x, y)
		if tiles[y][x][1] == types.grass then
			tiles[y][x][1] = types.shrub
		end
	end)
end

local NEIGHBOR_OFFSETS = {
	{ -1, -1 },
	{ 0, -1 },
	{ 1, -1 },
	{ -1, 0 },
	{ 1, 0 },
	{ -1, 1 },
	{ 0, 1 },
	{ 1, 1 },
}

function city_generator:find_dist()
	local falloff = gen_cfg.civ_falloff
	local steps = {}
	for y = 1, self.max_y do
		steps[y] = {}
	end

	local frontier, next_frontier = {}, {}

	local function seed(rect)
		for y = math.max(rect.y, 1), math.min(rect.y + rect.h - 1, self.max_y) do
			for x = math.max(rect.x, 1), math.min(rect.x + rect.w - 1, self.max_x) do
				if not steps[y][x] then
					steps[y][x] = 0
					table.insert(frontier, { x, y })
				end
			end
		end
	end

	for _, road in ipairs(self.roads) do
		seed(road)
	end
	for _, building in ipairs(self.buildings) do
		seed(building)
	end

	for step = 1, falloff do
		for _, cell in ipairs(frontier) do
			local cx, cy = cell[1], cell[2]
			for _, offset in ipairs(NEIGHBOR_OFFSETS) do
				local nx, ny = cx + offset[1], cy + offset[2]
				if utils.in_bounds(nx, ny, self.max_x, self.max_y) and not steps[ny][nx] then
					steps[ny][nx] = step
					table.insert(next_frontier, { nx, ny })
				end
			end
		end
		frontier, next_frontier = next_frontier, {}
	end

	self.distance = {}
	for y = 1, self.max_y do
		local row, step_row = {}, steps[y]
		for x = 1, self.max_x do
			local step = step_row[x]
			row[x] = step and step / falloff or 1
		end
		self.distance[y] = row
	end
end

function city_generator:make_road(tiles, road)
	local map = require("src.map.map")

	for y = road.y, road.y + road.h - 1 do
		for x = road.x, road.x + road.w - 1 do
			if love.math.random(1, gen_cfg.road_skip_chance) ~= gen_cfg.road_skip_chance then
				tiles[y][x][1] = types.road
			end
		end
	end
	local step = gen_cfg.lamp_step
	if road.w > road.h then
		for x = road.x + step, road.x + road.w - 1, step do
			if love.math.random() >= gen_cfg.lamp_skip_chance then
				local ly = love.math.random() < 0.5 and road.y - 1 or road.y + road.h
				if map:is_tile_free(x, ly, 1) then
					entities.add_from_template("street_lamp", x, ly, 1)
				end
			end
		end
	else
		for y = road.y + step, road.y + road.h - 1, step do
			if love.math.random() >= gen_cfg.lamp_skip_chance then
				local lx = love.math.random() < 0.5 and road.x - 1 or road.x + road.w
				if map:is_tile_free(lx, y, 1) then
					entities.add_from_template("street_lamp", lx, y, 1)
				end
			end
		end
	end
end

local function shape_footprint(inset, road_side)
	local cap_w = math.max(gen_cfg.min_building_size, math.floor(inset.h * gen_cfg.max_building_aspect))
	local cap_h = math.max(gen_cfg.min_building_size, math.floor(inset.w * gen_cfg.max_building_aspect))
	local w = math.min(inset.w, cap_w)
	local h = math.min(inset.h, cap_h)

	local slack_x, slack_y = inset.w - w, inset.h - h
	local dx, dy
	if road_side == "west" then
		dx = 0
	elseif road_side == "east" then
		dx = slack_x
	else
		dx = love.math.random(0, slack_x)
	end
	if road_side == "north" then
		dy = 0
	elseif road_side == "south" then
		dy = slack_y
	else
		dy = love.math.random(0, slack_y)
	end

	return { x = inset.x + dx, y = inset.y + dy, w = w, h = h }
end

local function make_wing(rect)
	local vertical = rect.w >= rect.h
	local split_span = vertical and rect.w or rect.h
	local wing_span = vertical and rect.h or rect.w
	local min_span = 2 * gen_cfg.min_room_thickness
	if split_span < min_span or wing_span < min_span then
		return { rect }
	end

	local offset = love.math.random(gen_cfg.min_room_thickness, split_span - gen_cfg.min_room_thickness)
	local wing_size = love.math.random(gen_cfg.min_room_thickness, wing_span - gen_cfg.min_room_thickness)
	local a, b, _ = utils.split_rect(rect, vertical, offset, -1)
	if love.math.random() < 0.5 then
		a, b = b, a
	end
	local near, far = utils.split_rect(b, not vertical, wing_size)
	local wing = love.math.random() < 0.5 and near or far

	return { a, wing }
end

local function make_room(rects, depth)
	depth = depth or 1
	local new_rects = {}
	for _, rect in ipairs(rects) do
		local vertical = rect.w >= rect.h
		local split_span = vertical and rect.w or rect.h
		if
			split_span >= 2 * gen_cfg.min_room_thickness
			and (split_span >= gen_cfg.max_room_size or love.math.random() < gen_cfg.room_split_chance)
		then
			local offset = love.math.random(gen_cfg.min_room_thickness, split_span - gen_cfg.min_room_thickness)
			local a, b, _ = utils.split_rect(rect, vertical, offset, -1)
			local pieces = { a, b }
			if depth < gen_cfg.max_room_split_depth then
				pieces = make_room(pieces, depth + 1)
			end
			for _, piece in ipairs(pieces) do
				table.insert(new_rects, piece)
			end
		else
			table.insert(new_rects, rect)
		end
	end
	return new_rects
end

function city_generator:build_building(tiles, lot)
	local map = require("src.map.map")

	local ml, mr, mt, mb =
		love.math.random(1, gen_cfg.building_margin),
		love.math.random(1, gen_cfg.building_margin),
		love.math.random(1, gen_cfg.building_margin),
		love.math.random(1, gen_cfg.building_margin)
	local bw, bh = lot.w - ml - mr, lot.h - mt - mb

	local inset = { x = lot.x + ml, y = lot.y + mt, w = bw, h = bh }
	if bw >= gen_cfg.min_building_size and bh >= gen_cfg.min_building_size then
		local roll = love.math.random()
		if roll < gen_cfg.building_chance then
			local road_side = self:nearest_road_side(inset)
			local footprint = shape_footprint(inset, road_side)
			local rects = { footprint }
			roll = love.math.random()
			if roll < gen_cfg.wing_chance then
				rects = make_wing(footprint)
			end
			rects = make_room(rects)
			local building, parts =
				features.make_building(tiles, rects, features.roll_height("wall", self.max_z), road_side)
			table.insert(self.buildings, building)
			for _, part in ipairs(parts) do
				features.scatter_count(tiles, part, love.math.random(2), function(x, y)
					if not map:is_tile_free(x, y, 1) then
						return false
					end

					entities.add_from_template(utils.pick({ "crate", "barricade", "chest" }), x, y, 1)
					return true
				end)
			end
		else
			features.scatter(tiles, lot, gen_cfg.monster_chance, function(x, y)
				local monster = utils.pick_weighted(gen_cfg.monsters)
				if monster then
					entities.add_from_template(monster.name, x, y, 1)
				end
			end)
		end
	end
end

function city_generator:load(tiles, map_max_y, map_max_x, map_max_z, map_min_z)
	self.max_y = map_max_y
	self.max_x = map_max_x
	self.max_z = map_max_z
	self.min_z = map_min_z
	self.lots = {}
	self.roads = {}
	self.buildings = {}
	local root = { x = 1, y = 1, w = self.max_x, h = self.max_y }
	self.noise_ox = love.math.random() * 1000
	self.noise_oy = love.math.random() * 1000
	features.load(self.max_x, self.max_y)

	lots.subdivide(root, gen_cfg.subdivide_depth, self.lots, self.roads)

	for _, road in ipairs(self.roads) do
		self:make_road(tiles, road)
	end
	for _, lot in ipairs(self.lots) do
		self:build_building(tiles, lot)
	end
	self:find_dist()
	self:wild(1, 1, map_max_x, map_max_y, tiles, root)
end

return city_generator
