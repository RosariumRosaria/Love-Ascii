local types = require("map.tile_types")
local gen_cfg = require("config.generation_config")
local lots = require("map.lots")
local features = require("map.features")
local entities = require("entities.entities")
local utils = require("utils")
local city_generator = { max_x = nil, max_y = nil, max_z = nil, lots = {}, roads = {} }

function city_generator:get_lots()
	return self.lots
end

function city_generator:get_roads()
	return self.roads
end

function city_generator:load(tiles, map_max_y, map_max_x, map_max_z, map_min_z)
	local map = require("map.map")
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
			if love.math.random(1, gen_cfg.shrub_chance) == gen_cfg.shrub_chance then
				tiles[y][x][1] = types.shrub
			end
		end
	end
	for _, road in ipairs(self.roads) do
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

	for _, lot in ipairs(self.lots) do
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
				local building = features.make_building(
					tiles,
					lot.x + ml,
					lot.y + mt,
					bw,
					bh,
					features.roll_height("wall", self.max_z),
					self.max_x,
					self.max_y
				)
				features.scatter_count(tiles, building, love.math.random(3), function(x, y)
					if not map:is_tile_free(x, y, 1) then
						return false
					end

					entities.add_from_template(utils.pick({ "crate", "barricade", "chest" }), x, y, 1)
					return true
				end, self.max_x, self.max_y)
			elseif roll < gen_cfg.building_chance + gen_cfg.copse_chance then
				local variance = gen_cfg.copse_density_variance
				local tree_density_adjusted = gen_cfg.copse_density - variance + (variance * love.math.random())

				features.scatter(tiles, inset, tree_density_adjusted, function(x, y)
					features.place("tree", x, y, tiles, self.max_z)
				end, self.max_x, self.max_y)
			else
				features.scatter(tiles, lot, 0.003, function(x, y)
					entities.add_from_template("zombie", x, y, 1)
				end, self.max_x, self.max_y)
				features.scatter(tiles, lot, 0.003, function(x, y)
					entities.add_from_template("shambler", x, y, 1)
				end, self.max_x, self.max_y)
				features.scatter(tiles, lot, 0.001, function(x, y)
					entities.add_from_template("vampire", x, y, 1)
				end, self.max_x, self.max_y)
				features.scatter(tiles, lot, 0.003, function(x, y)
					entities.add_from_template("rat", x, y, 1)
				end, self.max_x, self.max_y)
				features.scatter(tiles, lot, 0.001, function(x, y)
					entities.add_from_template("ogre", x, y, 1)
				end, self.max_x, self.max_y)
			end
		end
	end
end

return city_generator
