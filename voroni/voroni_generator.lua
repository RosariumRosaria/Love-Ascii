local tile_types = require("map.debug_tiles")

local voroni_generator = {
	width = nil,
	height = nil,
	map = nil,
	seeds = nil,
	regions = nil,
	regionGrid = nil,
	city = nil,
}

local main_road_size = 3
local off_road_size = 2

local function contains(tbl, val)
	for _, v in ipairs(tbl) do
		if v == val then
			return true
		end
	end
	return false
end

local function getDistance(pos1, pos2)
	return (pos1[1] - pos2[1]) ^ 2 + (pos1[2] - pos2[2]) ^ 2
end

local function get_nearest_seed(seeds, pos)
	local nearest_seed = nil
	local nearest_distance = nil
	for i, seed in ipairs(seeds) do
		local distance = getDistance(seed, pos)
		if not nearest_distance or distance < nearest_distance then
			nearest_distance = distance
			nearest_seed = i
		end
	end
	return nearest_seed
end

function voroni_generator:get_regions()
	return self.regions
end

function voroni_generator:get_seeds()
	return self.seeds
end

function voroni_generator:inbounds(x, y)
	return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

function voroni_generator:find_regions()
	for y = 1, self.height do
		for x = 1, self.width do
			local nearestSeed = get_nearest_seed(self.seeds, { x, y })
			self.regionGrid[y][x] = nearestSeed
		end
	end
end

function voroni_generator:find_region_metadata()
	for _, reg in pairs(self.regions) do
		reg.sumX, reg.sumY, reg.count = 0, 0, 0
	end

	for y = 1, self.height do
		for x = 1, self.width do
			local id = self.regionGrid[y][x]
			local reg = self.regions[id]
			reg.sumX = reg.sumX + x
			reg.sumY = reg.sumY + y
			reg.count = reg.count + 1
		end
	end

	for _, reg in pairs(self.regions) do
		if reg.count ~= 0 then
			reg.centroid_x = math.floor(reg.sumX / reg.count + 0.5)
			reg.centroid_y = math.floor(reg.sumY / reg.count + 0.5)
		end
	end
end

function voroni_generator:sow_seeds(seedNum)
	for i = 1, seedNum do
		self.regions[i] = {}
		self.regions[i].sumX = 0
		self.regions[i].sumY = 0
		self.regions[i].count = 0
		local x = math.random(1, self.width)
		local y = math.random(1, self.height)
		table.insert(self.seeds, { x, y })
	end
end

function voroni_generator:lloyd()
	for i, seed in ipairs(self.seeds) do
		local reg = self.regions[i]
		if reg.count > 0 then
			seed[1] = reg.centroid_x
			seed[2] = reg.centroid_y
		else
			seed[1] = math.random(1, self.width)
			seed[2] = math.random(1, self.height)
		end
	end

	self:find_regions()
	self:find_region_metadata()
	self:find_city(5)
	self:paint_regions(self.city, "dark_gray")
	local roads = self:prims()
	self:pave_main_roads(roads)
end

function voroni_generator:paint_regions(ids, color)
	local typeKeys = tile_types.typeKeys
	for y = 1, self.height do
		for x = 1, self.width do
			local id = self.regionGrid[y][x]
			local key = typeKeys[(id % #typeKeys) + 1]
			self.map[y][x][1] = tile_types[key]

			if contains(ids, id) then
				self.map[y][x][1] = tile_types[color]
			end
		end
	end
end

function voroni_generator:find_neighbors()
	local neighbors = {}
	for i = 1, #self.regions do
		neighbors[i] = {}
	end
	for y = 1, self.height do
		for x = 1, self.width do
			local a = self.regionGrid[y][x]
			local b = (x < self.width) and self.regionGrid[y][x + 1] or a
			local c = (y < self.height) and self.regionGrid[y + 1][x] or a
			if a ~= b then
				neighbors[a][b], neighbors[b][a] = true, true
			end
			if a ~= c then
				neighbors[a][c], neighbors[c][a] = true, true
			end
		end
	end
	for i = 1, #self.regions do
		local list = {}
		for ii, _ in pairs(neighbors[i]) do
			table.insert(list, ii)
		end
		self.regions[i].neighbors = list
	end
end

function voroni_generator:expand_city(city_size, id)
	table.insert(self.city, id)
	if city_size > 1 then
		city_size = city_size - 1
		for _, neighbor_id in ipairs(self.regions[id].neighbors) do
			if not contains(self.city, neighbor_id) then
				self:expand_city(city_size, neighbor_id)
			end
		end
	end
end

function voroni_generator:find_city(city_size)
	self.city = {}
	local cy = math.floor(self.height / 2)
	local cx = math.floor(self.width / 2)
	local center_region = self.regionGrid[cy][cx]
	self:expand_city(city_size, center_region)
end

function voroni_generator:load(width, height, map, regions)
	math.randomseed(os.time())
	self.width = width or self.width
	self.height = height or self.height
	self.map = map or self.map
	self.regionGrid = {}
	for y = 1, self.height do
		self.regionGrid[y] = {}
		for x = 1, self.width do
			self.regionGrid[y][x] = nil
		end
	end
	self:reload(regions or 100)
end

function voroni_generator:prims()
	local in_mst = {}
	local mst = {}

	for _, id in ipairs(self.city) do
		in_mst[id] = false
	end

	local cy = math.floor(self.height / 2)
	local cx = math.floor(self.width / 2)
	local center_id = self.regionGrid[cy][cx]

	in_mst[center_id] = true

	local i = 1
	while i < #self.city do
		local minDist = nil
		local minID = nil
		local parentID = nil
		for _, id in ipairs(self.city) do
			if in_mst[id] then
				for _, neighbor_id in ipairs(self.regions[id].neighbors) do
					if not in_mst[neighbor_id] and contains(self.city, neighbor_id) then
						local dist = getDistance(
							{ self.regions[id].centroid_x, self.regions[id].centroid_y },
							{ self.regions[neighbor_id].centroid_x, self.regions[neighbor_id].centroid_y }
						)
						if not minDist or minDist > dist then
							minID = neighbor_id
							parentID = id
							minDist = dist
						end
					end
				end
			end
		end
		if not minID then
			break
		end
		in_mst[minID] = true
		table.insert(mst, { parentID, minID, minDist })
		i = i + 1
	end
	return mst
end

function voroni_generator:pave_circle(cx, cy, radius)
	local rad_dist = radius * radius
	for y = -radius, radius do
		for x = -radius, radius do
			local px, py = x + cx, y + cy
			if getDistance({ px, py }, { cx, cy }) < rad_dist then
				if self:inbounds(py, px) then
					self.map[py][px][1] = tile_types["white"]
				end
			end
		end
	end
end

function voroni_generator:pave_road(road, radius)
	local x0 = self.regions[road[1]].centroid_x
	local y0 = self.regions[road[1]].centroid_y
	local x1 = self.regions[road[2]].centroid_x
	local y1 = self.regions[road[2]].centroid_y

	local dx = math.abs(x1 - x0)
	local dy = math.abs(y1 - y0)

	local swapped = false
	if dy > dx then
		x0, y0 = y0, x0
		x1, y1 = y1, x1
		dx, dy = dy, dx
		swapped = true
	end

	local sx = (x0 < x1) and 1 or -1
	local sy = (y0 < y1) and 1 or -1

	local x, y = x0, y0
	local err = math.floor(dx / 2)

	while true do
		local px, py = (swapped and y or x), (swapped and x or y)

		self:pave_circle(px, py, radius)
		if x == x1 and y == y1 then
			break
		end

		x = x + sx
		err = err - dy
		if err < 0 then
			y = y + sy
			err = err + dx
		end
	end
end

function voroni_generator:pave_main_roads(roads)
	for _, road in ipairs(roads) do
		self:pave_road(road, main_road_size)
	end
end

function voroni_generator:reload(regions)
	self.seeds = {}
	self.regions = {}
	self:sow_seeds(regions)
	self:find_regions()
	self:find_region_metadata()
	self:find_neighbors()
	self:find_city(5)
	self:paint_regions(self.city, "dark_gray")
	local roads = self:prims()
	self:pave_main_roads(roads)
end

return voroni_generator
