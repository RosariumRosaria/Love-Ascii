local tile_types = require("map.debug_tiles")

local voroni_generator = {
  width = nil,
  height = nil,
  map = nil,
  seeds = nil,
  regions = nil,
  regionGrid = nil,
}

local function getNearestSeed(seeds, pos)
  local closestSeed = nil
  local closestDistance = nil
  for i, seed in ipairs(seeds) do
    local dist = (seed[1] - pos[1]) ^ 2 + (seed[2] - pos[2]) ^ 2
    if not closestDistance or dist < closestDistance then
      closestDistance = dist
      closestSeed = i
    end
  end
  return closestSeed
end

function voroni_generator:getRegions()
  return self.regions
end

function voroni_generator:getSeeds()
  return self.seeds
end

function voroni_generator:findRegions()
  for y = 1, self.height do
    for x = 1, self.width do
      local nearestSeed = getNearestSeed(self.seeds, { x, y })
      self.regionGrid[y][x] = nearestSeed
    end
  end
end

function voroni_generator:getRegionMetadata()
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
      reg.centroidX = reg.sumX / reg.count
      reg.centroidY = reg.sumY / reg.count
    end
  end
end

function voroni_generator:sowSeeds(seedNum)
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
      seed[1] = reg.centroidX
      seed[2] = reg.centroidY
    else
      seed[1] = math.random(1, self.width)
      seed[2] = math.random(1, self.height)
    end
  end

  self:findRegions()
  self:getRegionMetadata()
  self:paintRegions()
end

function voroni_generator:paintRegions()
  local typeKeys = tile_types.typeKeys
  for y = 1, self.height do
    for x = 1, self.width do
      local id = self.regionGrid[y][x]
      local key = typeKeys[(id % #typeKeys) + 1]
      self.map[y][x][1] = tile_types[key]
    end
  end
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
  self:reload(regions)
end

function voroni_generator:reload(regions)
  self.seeds = {}
  self.regions = {}

  self:sowSeeds(regions)
  self:findRegions()
  self:getRegionMetadata()
  self:paintRegions()
end

return voroni_generator
