local map = require("map.map")
local voroni_generator = require("voroni.voroni_generator")

local visualizer = {}

function visualizer:drawMap()
  for y = 1, self.mapHeight do
    for x = 1, self.mapWidth do
      local tile = map:getTile(x, y, 1)
      local tileColor = tile and tile.color
      if tileColor then
        love.graphics.setColor(tileColor)
      end
      love.graphics.rectangle(
        "fill",
        self.startX + (x - 1) * self.scale,
        self.startY + (y - 1) * self.scale,
        self.scale,
        self.scale
      )
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function visualizer:drawPointSet()
  local pointSet = voroni_generator:getRegions()
  if pointSet then
    for _, point in ipairs(pointSet) do
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.circle(
        "fill",
        self.startX + (point.centroidX - 1) * self.scale,
        self.startY + (point.centroidY - 1) * self.scale,
        self.scale,
        self.scale
      )
    end
  end

  pointSet = voroni_generator:getSeeds()
  if pointSet then
    for _, point in ipairs(pointSet) do
      love.graphics.setColor(1, 0, 0, 1)
      love.graphics.circle(
        "fill",
        self.startX + (point[1] - 1) * self.scale,
        self.startY + (point[2] - 1) * self.scale,
        self.scale,
        self.scale
      )
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function visualizer:draw()
  -- Cache layout/state on self so helpers use it (and self is no longer "unused")
  self.screenWidth = love.graphics.getWidth()
  self.screenHeight = love.graphics.getHeight()
  self.mapWidth = map:getWidth()
  self.mapHeight = map:getHeight()
  self.scale = math.min(self.screenWidth / self.mapWidth, self.screenHeight / self.mapHeight)
  self.startX = (self.screenWidth - self.mapWidth * self.scale) / 2
  self.startY = (self.screenHeight - self.mapHeight * self.scale) / 2

  self:drawMap()
  self:drawPointSet()
end

return visualizer
