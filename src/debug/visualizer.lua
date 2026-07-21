local map = require("src.map.map")
local entities = require("src.sim.entities")
local city_generator = require("src.map.city_generator")

local visualizer = {
	visible = false,
}

function visualizer:toggle()
	self.visible = not self.visible
end

function visualizer:draw_map()
	for y = 1, self.map_max_y do
		for x = 1, self.map_max_x do
			local tile = map:get_tile(x, y, 1)
			local tile_color = tile and tile.color
			if tile_color then
				love.graphics.setColor(tile_color)
			end
			love.graphics.rectangle(
				"fill",
				self.start_x + (x - 1) * self.scale,
				self.start_y + (y - 1) * self.scale,
				self.scale,
				self.scale
			)
		end
	end
	love.graphics.setColor(1, 1, 1, 1)
end

function visualizer:draw_player()
	local player = entities.player
	if not player then
		return
	end
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.circle(
		"fill",
		self.start_x + (player.x - 1) * self.scale,
		self.start_y + (player.y - 1) * self.scale,
		self.scale * 2
	)
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.circle(
		"line",
		self.start_x + (player.x - 1) * self.scale,
		self.start_y + (player.y - 1) * self.scale,
		self.scale * 2
	)
	love.graphics.setColor(1, 1, 1, 1)
end

function visualizer:draw_lots()
	local lots = city_generator:get_lots()
	if not lots then
		return
	end
	love.graphics.setColor(1, 1, 0, 0.3)
	for _, r in ipairs(lots) do
		love.graphics.rectangle(
			"fill",
			self.start_x + (r.x - 1) * self.scale,
			self.start_y + (r.y - 1) * self.scale,
			r.w * self.scale,
			r.h * self.scale
		)
	end
	love.graphics.setColor(1, 1, 1, 1)
end

function visualizer:draw_roads()
	local roads = city_generator:get_roads()
	if not roads then
		return
	end
	love.graphics.setColor(0, 1, 1, 1)
	for _, r in ipairs(roads) do
		love.graphics.rectangle(
			"line",
			self.start_x + (r.x - 1) * self.scale,
			self.start_y + (r.y - 1) * self.scale,
			r.w * self.scale,
			r.h * self.scale
		)
	end
	love.graphics.setColor(1, 1, 1, 1)
end

function visualizer:draw()
	if not self.visible then
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
	self:draw_player()
end

return visualizer
