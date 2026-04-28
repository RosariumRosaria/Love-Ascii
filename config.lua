local config = {}

function config:load()
	local scale = 2
	self.font = love.graphics.newFont(16 * scale)
	self.small_font = love.graphics.newFont(16)
	love.graphics.setFont(self.font)
	self.tile_size = self.font:getHeight()
	self.small_tile_size = self.tile_size / scale
end

return config
