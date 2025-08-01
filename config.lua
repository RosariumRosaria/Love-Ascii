local config = {}

function config:load()
  local scale = 2
  self.font = love.graphics.newFont(16 * scale)
  self.smallFont = love.graphics.newFont(16)
  love.graphics.setFont(self.font)

  self.tileSize = self.font:getHeight()
  self.smallTileSize = self.tileSize / scale
end

return config
