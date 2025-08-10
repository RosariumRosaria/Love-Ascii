local fov_handler = require("fov.fov_handler")
local city_generator = require("map.city_generator")
local types = require("map.tile_types")
local voroni_generator = require("voroni.voroni_generator")

local map = {
  width = nil,
  height = nil,
  depth = nil,
  tiles = {},
  visible = {},
  explored = {},
}

function map:inbounds(x, y)
  return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

function map:getTile(x, y, z)
  if not map:inbounds(x, y) then
    return nil
  end
  if not self.tiles[y] or not self.tiles[y][x][z] then
    return nil
  end

  return self.tiles[y][x][z]
end

function map:walkable(x, y, z)
  if not self:inbounds(x, y) then
    return false
  end
  if not self.tiles[y] or not self.tiles[y][x][z] then
    return false
  end
  return self.tiles[y][x][z].walkable
end

function map:isVisible(x, y)
  if not self:inbounds(x, y) then
    return false
  end
  return self.visible[y][x]
end

function map:isExplored(x, y)
  if not self:inbounds(x, y) then
    return false
  end
  return self.explored[y][x]
end

function map:getWidth()
  return self.width
end

function map:getHeight()
  return self.height
end

function map:getTiles()
  return self.tiles
end

function map:load(width, height, depth, mapType)
  -- math.randomseed(os.time())
  self.width = width or 10
  self.height = height or 10
  self.depth = depth or 5
  for y = 1, self.height do
    self.tiles[y] = {}
    self.visible[y] = {}
    self.explored[y] = {}
    for x = 1, self.width do
      self.tiles[y][x] = {}
      self.visible[y][x] = false
      self.explored[y][x] = false
      self.tiles[y][x][1] = types.grass
    end
  end
  if mapType == "town" then
    -- TODO Hardcoded for 205, should be changed
    voroni_generator:load(self.width, self.height, self.tiles, 30)

    --city_generator:makeTown(205, self.tiles, self.height, self.width, self.depth)
  end
end

function map:updateVisibility(centerX, centerY, radius)
  for y = 1, self.height do -- TODO SO INEFFICIENT, but works for now
    for x = 1, self.width do
      self.visible[y][x] = false
    end
  end

  fov_handler.refreshVisibility(centerX, centerY, radius, self.width, self.height, self.tiles, self.visible, true)

  for y = 1, self.height do -- TODO SO INEFFICIENT, but works for now
    for x = 1, self.width do
      if self.visible[y][x] then
        self.explored[y][x] = true
      end
    end
  end
end

return map
