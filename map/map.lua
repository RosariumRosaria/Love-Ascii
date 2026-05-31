local fov_handler = require("fov.visibility")
local lighting = require("fov.lighting")
local city_generator = require("map.city_generator")
local types = require("map.tile_types")
local utils = require("utils")
local gen_cfg = require("config.generation_config")
local render_config = require("config.render_config")
local entities = require("entities.entities")
local statuses = require("statuses.statuses")

local map = {
	max_x = nil,
	max_y = nil,
	max_z = nil,
	min_z = nil,
	tiles = {},
	visible = {},
	lighting = {},
	explored = {},
	prev_visible = {},
}

function map:apply_on_step(entity)
	local tile_stack = map:get_tile_stack(entity.x, entity.y)
	statuses.apply_from_tile(entity, tile_stack)
end

function map:get_tile_stack(x, y)
	if not map:in_bounds(x, y) then
		return nil
	end
	return self.tiles[y][x]
end

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

function map:is_tile_free(x, y, z, skip_entities)
	if not self:walkable(x, y, z) then
		return false
	end
	for _, ent in ipairs(entities.get_entities_at(x, y, z)) do
		if (not skip_entities or not skip_entities[ent]) and not entities.get_tag_entity(ent, "walkable") then
			return false
		end
	end
	return true
end

function map:is_visible(x, y)
	if not self:in_bounds(x, y) then
		return false
	end
	return self.visible[y][x]
end

function map:is_transparent(x, y)
	local stack = self.tiles[y][x]
	if not stack[1].transparent then
		return false
	end
	if #stack > 1 and not stack[2].transparent then
		return false
	end
	if entities.get_tag_location(x, y, 1, "solid") then
		return false
	end
	return true
end

function map:get_lighting_tile(x, y)
	--TODO: This is a hack to prevent lighting from showing on the sides of solid tiles.
	--Should be replaced with somethign more robust (Each Tile stores NSWE for whether it's lit from that direction, and lighting checks those
	-- This would also require the system to know where the viewer is, to see which light to use
	if not self:is_transparent(x, y) then
		for _, n in ipairs(utils.get_neighbors(x, y, self.max_x, self.max_y)) do
			if self:is_transparent(n.x, n.y) and self:is_visible(n.x, n.y) then
				local light = self.lighting[n.y][n.x]
				if (light.r + light.g + light.b) > render_config.lighting.ambient then
					return self.lighting[y][x]
				end
			end
		end
		return { r = 0, g = 0, b = 0 }
	end
	return self.lighting[y][x]
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
	math.randomseed(os.time())
	self.max_x = max_x or 10
	self.max_y = max_y or 10
	self.max_z = max_z or 5
	self.min_z = min_z or -2
	for y = 1, self.max_y do
		self.tiles[y] = {}
		self.visible[y] = {}
		self.explored[y] = {}
		self.lighting[y] = {}
		for x = 1, self.max_x do
			self.tiles[y][x] = {}
			self.visible[y][x] = false
			self.explored[y][x] = false
			self.lighting[y][x] = { r = 0, g = 0, b = 0, sources = {} }
			self.tiles[y][x][1] = types.grass
		end
	end
	if map_type == "town" then
		city_generator:load(self.tiles, self.max_y, self.max_x, self.max_z, self.min_z)
	end
end

function map:update_visibility(center_x, center_y, radius)
	for _, pos in ipairs(self.prev_visible) do
		self.visible[pos[2]][pos[1]] = false
	end
	self.prev_visible = {}

	fov_handler.refresh_visibility(center_x, center_y, radius, self.max_x, self.max_y, self.tiles, self.visible, true)
	lighting.recompute(self.max_x, self.max_y, self.tiles, self.lighting, center_x, center_y, radius)
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
