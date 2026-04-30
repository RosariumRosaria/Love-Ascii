local map = require("map.map")
local voroni_generator = require("voroni.voroni_generator")

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

function visualizer:draw_point_set()
	local point_set = voroni_generator:get_regions()

	if point_set then
		for _, point in ipairs(point_set) do
			love.graphics.setColor(0, 0, 0, 1)
			love.graphics.circle(
				"fill",
				self.start_x + (point.centroid_x - 1) * self.scale,
				self.start_y + (point.centroid_y - 1) * self.scale,
				self.scale * 2
			)
		end
	end

	point_set = voroni_generator:get_seeds()
	if point_set then
		for _, point in ipairs(point_set) do
			love.graphics.setColor(1, 0, 0, 1)
			love.graphics.circle(
				"fill",
				self.start_x + (point[1] - 1) * self.scale,
				self.start_y + (point[2] - 1) * self.scale,
				self.scale * 2
			)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function visualizer:draw()
	if not self.visible then return end
	self.screen_width = love.graphics.getWidth()
	self.screen_height = love.graphics.getHeight()
	self.map_max_x = map:get_max_x()
	self.map_max_y = map:get_max_y()
	self.scale = math.min(self.screen_width / self.map_max_x, self.screen_height / self.map_max_y)
	self.start_x = (self.screen_width - self.map_max_x * self.scale) / 2
	self.start_y = (self.screen_height - self.map_max_y * self.scale) / 2
	self:draw_map()
	self:draw_point_set()
end

return visualizer
