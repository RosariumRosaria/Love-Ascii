local fov_handler = require("fov.fov_handler")
local city_generator = require("map.city_generator")
local types = require("map.tile_types")
local voroni_generator = require("voroni.voroni_generator")
local utils = require("utils")
local gen_cfg = require("config.generation_config")

local map = {
	max_x = nil,
	max_y = nil,
	max_z = nil,
	min_z = nil,
	tiles = {},
	visible = {},
	explored = {},
	prev_visible = {},
}

function map:in_bounds(x, y)
	return utils.in_bounds(x, y, self.max_x, self.max_y)
end

function map:get_tile(x, y, z)
	if not map:in_bounds(x, y) then
		return nil
	end
	if not self.tiles[y] or not self.tiles[y][x][z] then
		return nil
	end

	return self.tiles[y][x][z]
end

function map:walkable(x, y, z)
	if not self:in_bounds(x, y) then
		return false
	end
	if not self.tiles[y] or not self.tiles[y][x][z] then
		return false
	end
	return self.tiles[y][x][z].walkable
end

function map:is_visible(x, y)
	if not self:in_bounds(x, y) then
		return false
	end
	return self.visible[y][x]
end

function map:is_explored(x, y)
	if not self:in_bounds(x, y) then
		return false
	end
	return self.explored[y][x]
end

function map:get_max_x()
	return self.max_x
end

function map:get_max_y()
	return self.max_y
end

function map:get_tiles()
	return self.tiles
end

function map:load(max_x, max_y, max_z, min_z, map_type)
	-- math.randomseed(os.time())
	self.max_x = max_x or 10
	self.max_y = max_y or 10
	self.max_z = max_z or 5
	self.min_z = min_z or -2
	for y = 1, self.max_y do
		self.tiles[y] = {}
		self.visible[y] = {}
		self.explored[y] = {}
		for x = 1, self.max_x do
			self.tiles[y][x] = {}
			self.visible[y][x] = false
			self.explored[y][x] = false
			self.tiles[y][x][1] = types.grass
		end
	end
	if map_type == "town" then
		--voroni_generator:load(self.max_x, self.max_y, self.tiles, 125)
		-- TODO Hardcoded, should be changed
		city_generator:make_town(205, self.tiles, self.max_y, self.max_x, self.max_z, self.min_z)

		-- DEBUG: water pool around (30, 30)
		local radius = 8
		for dy = -radius, radius do
			for dx = -radius, radius do
				local tx, ty = 30 + dx, 30 + dy
				if utils.in_bounds(tx, ty, self.max_x, self.max_y) and utils.in_radius(dx, dy, radius) then
					self.tiles[ty][tx][-2] = types.water
					self.tiles[ty][tx][1] = types.air
				end
			end
		end

		-- DEBUG: bridge across the pool (east-west at y=30)
		for bx = 30 - radius, 30 + radius do
			if utils.in_bounds(bx, 30, self.max_x, self.max_y) then
				self.tiles[30][bx][1] = types.floor
			end
		end
	end
end

function map:update_visibility(center_x, center_y, radius)
	for _, pos in ipairs(self.prev_visible) do
		self.visible[pos[2]][pos[1]] = false
	end
	self.prev_visible = {}

	fov_handler.refresh_visibility(center_x, center_y, radius, self.max_x, self.max_y, self.tiles, self.visible, true)

	local x1 = math.max(1, center_x - radius)
	local x2 = math.min(self.max_x, center_x + radius)
	local y1 = math.max(1, center_y - radius)
	local y2 = math.min(self.max_y, center_y + radius)
	for y = y1, y2 do
		for x = x1, x2 do
			if self.visible[y][x] then
				self.explored[y][x] = true
				self.prev_visible[#self.prev_visible + 1] = { x, y }
			end
		end
	end
end

return map
