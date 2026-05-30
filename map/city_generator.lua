local types = require("map.tile_types")
local gen_cfg = require("config.generation_config")
local lots = require("map.lots")
local structures = require("map.structures")
local city_generator = { max_x = nil, max_y = nil, max_z = nil, lots = {}, roads = {} }

function city_generator:get_lots()
	return self.lots
end

function city_generator:get_roads()
	return self.roads
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

	-- map:load already seeds every ground cell with grass; only paint shrubs on top here.
	for y = 1, map_max_y do
		for x = 1, map_max_x do
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
				structures.make_building(
					tiles,
					lot.x + m,
					lot.y + m,
					bw,
					bh,
					structures.roll_height("wall", self.max_z),
					self.max_x,
					self.max_y
				)
			elseif roll < gen_cfg.building_chance + gen_cfg.copse_chance then
				local cx = lot.x + m + math.floor(bw / 2)
				local cy = lot.y + m + math.floor(bh / 2)
				local radius = math.floor(math.min(bw, bh) / 2)
				local variance = gen_cfg.copse_density_variance
				local tree_density_adjusted = gen_cfg.copse_density - variance + (variance * math.random())
				structures.make_copse(tiles, cx, cy, radius, tree_density_adjusted, self.max_x, self.max_y, self.max_z)
			end
		end
	end
end

return city_generator
