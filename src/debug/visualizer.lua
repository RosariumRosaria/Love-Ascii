local map = require("src.map.map")
local entities = require("src.sim.entities")
local city_generator = require("src.map.city_generator")
local utils = require("src.utils")
local MODE_COUNT = 3

local visualizer = {
	mode = 0,
}

function visualizer:toggle()
	self.mode = (self.mode + 1) % MODE_COUNT
end

function visualizer:invalidate()
	self.tile_source = nil
	self.tile_cache = nil
end

function visualizer:tile_image()
	local tiles = map:get_tiles()
	if not tiles or not tiles[1] then
		return nil
	end
	local w, h = self.map_max_x, self.map_max_y
	if self.tile_source == tiles and self.tile_w == w and self.tile_h == h then
		return self.tile_cache
	end

	if w and h then
		local data = love.image.newImageData(w, h)
		local set = data.setPixel
		for y = 1, h do
			local row = tiles[y]
			for x = 1, w do
				local cell = row and row[x]
				local tile = cell and cell[1]
				local c = tile and tile.color
				if c then
					set(data, x - 1, y - 1, c[1], c[2], c[3], c[4] or 1)
				else
					set(data, x - 1, y - 1, 0, 0, 0, 1)
				end
			end
		end

		local image = love.graphics.newImage(data)
		image:setFilter("nearest", "nearest")
		self.tile_source = tiles
		self.tile_w, self.tile_h = w, h
		self.tile_cache = image
		return image
	end
end

function visualizer:draw_map()
	local image = self:tile_image()
	if not image then
		return
	end
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, self.start_x, self.start_y, 0, self.scale, self.scale)
end

function visualizer:draw_entity(entity)
	if not entity then
		return
	end
	local px = self.start_x + (entity.x - 1) * self.scale
	local py = self.start_y + (entity.y - 1) * self.scale

	local radius = math.max(self.scale * 2, 4)
	local color = entity.appearance.color[1] or { 1, 1, 1, 1 }

	if entity.mind and entity.mind.hunter then
		love.graphics.setColor(1, 0, 0, 0.8)
		local reach = radius * 3
		love.graphics.line(px - reach, py, px + reach, py)
		love.graphics.line(px, py - reach, px, py + reach)
	end
	love.graphics.setColor(color)
	love.graphics.circle("fill", px, py, radius)
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.circle("line", px, py, radius)
	love.graphics.setColor(1, 1, 1, 1)
end

function visualizer:draw_player()
	local player = entities.player
	if not player then
		return
	end
	local px = self.start_x + (player.x - 1) * self.scale
	local py = self.start_y + (player.y - 1) * self.scale

	local radius = math.max(self.scale * 2, 4)
	local reach = radius * 3

	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.line(px - reach, py, px + reach, py)
	love.graphics.line(px, py - reach, px, py + reach)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.circle("fill", px, py, radius)
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.circle("line", px, py, radius)
	love.graphics.setColor(1, 1, 1, 1)
end

local ward_hues = {
	{ 1, 0.4, 0.4 },
	{ 0.4, 1, 0.5 },
	{ 0.4, 0.6, 1 },
	{ 1, 0.9, 0.4 },
	{ 0.8, 0.5, 1 },
	{ 0.4, 1, 1 },
}

function visualizer:draw_wards()
	local wards = city_generator:get_wards()
	if not wards then
		return
	end
	for i, r in ipairs(wards) do
		local hue = ward_hues[(i - 1) % #ward_hues + 1]
		local x = self.start_x + (r.x - 1) * self.scale
		local y = self.start_y + (r.y - 1) * self.scale
		local w = r.w * self.scale
		local h = r.h * self.scale
		love.graphics.setColor(hue[1], hue[2], hue[3], 0.25)
		love.graphics.rectangle("fill", x, y, w, h)
		love.graphics.setColor(hue[1], hue[2], hue[3], 1)
		love.graphics.rectangle("line", x, y, w, h)
	end
	love.graphics.setColor(1, 1, 1, 1)
end

function visualizer:draw()
	if self.mode == 0 then
		return
	end
	self.screen_width = love.graphics.getWidth()
	self.screen_height = love.graphics.getHeight()
	self.map_max_x = map:get_max_x()
	self.map_max_y = map:get_max_y()
	self.scale = math.min(self.screen_width / self.map_max_x, self.screen_height / self.map_max_y)
	self.start_x = (self.screen_width - self.map_max_x * self.scale) / 2
	self.start_y = (self.screen_height - self.map_max_y * self.scale) / 2
	self:draw_map()

	if self.mode == 2 then
		local ents = entities.get_actors()
		for _, ent in ipairs(ents) do
			self:draw_entity(ent)
		end
	end
	if self.mode == 3 then
		self:draw_wards()
	end
	self:draw_player()
end

return visualizer
