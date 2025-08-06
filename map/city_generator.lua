local entities = require("entities.entities")
local types = require("map.tile_types")
local city_generator = { width = nil, height = nil, depth = nil }

function city_generator:inbounds(x, y, width, height) -- Can maybe moved to separate file
  return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

function city_generator:overlapRect(r1, r2)
  return not (
    r1.x + r1.width <= r2.x
    or r2.x + r2.width <= r1.x
    or r1.y + r1.height <= r2.y
    or r2.y + r2.height <= r1.y
  )
end

function city_generator:makeBuilding(roomStartX, roomStartY, width, height, depth, tiles)
  for y = 1, height do
    for x = 1, width do
      local tileX = roomStartX + x - 1
      local tileY = roomStartY + y - 1
      if self:inbounds(tileX, tileY, self.width, self.height) then
        if
          (x == 1 and y == 1)
          or (x == width and y == height)
          or (x == 1 and y == height)
          or (x == width and y == 1)
        then
          for z = 1, depth do
            tiles[tileY][tileX][z] = types.cWall
          end
        elseif x == 1 or x == width then
          for z = 1, depth do
            tiles[tileY][tileX][z] = types.hWall
          end
        elseif y == 1 or y == height then
          for z = 1, depth do
            tiles[tileY][tileX][z] = types.vWall
          end
        else
          tiles[tileY][tileX][1] = types.floor
        end
      end
    end
  end

  if width <= 2 or height <= 2 then
    return { x = roomStartX, y = roomStartY, width = width, height = height }
  end

  local function safeDoorStart(len)
    return math.random(2, math.max(2, len - 1))
  end

  local doorX = safeDoorStart(width)
  local doorY = safeDoorStart(height)

  local sides = {
    { x = roomStartX, y = roomStartY + doorY - 1, rotation = 0 }, -- left wall
    { x = roomStartX + width - 1, y = roomStartY + doorY - 1, rotation = 180 }, -- right wall
    { x = roomStartX + doorX - 1, y = roomStartY, rotation = 90 }, -- top wall
    { x = roomStartX + doorX - 1, y = roomStartY + height - 1, rotation = 270 }, -- bottom wall
  }

  local dir = math.random(1, 4)
  local dir2 = math.random(1, 4)

  for i, side in ipairs(sides) do
    if self:inbounds(side.x, side.y, self.width, self.height) then
      tiles[side.y][side.x][2] = types.air
      if dir == i or dir2 == i then
        tiles[side.y][side.x][1] = types.floor
        entities:addFromTemplate("door", side.x, side.y, 1, { rotation = side.rotation })
      else
        tiles[side.y][side.x][3] = types.air
        entities:addFromTemplate("window", side.x, side.y, 1, { rotation = side.rotation })
      end
    end
  end

  return {
    x = roomStartX,
    y = roomStartY,
    width = width,
    height = height,
  }
end

function city_generator:makeTown(roomCount, tiles, mapHeight, mapWidth, mapDepth)
  self.height = mapHeight
  self.width = mapWidth
  self.depth = mapDepth
  print(mapHeight, mapWidth)
  for y = 1, mapHeight do
    for x = 1, mapWidth do
      tiles[y][x][1] = types.grass
      if math.random(1, 15) == 15 then
        tiles[y][x][1] = types.shrub
      end
    end
  end

  local buildings = {}

  for i = 1, roomCount do
    local potentialBuilding
    local overLaps = true

    while overLaps do
      overLaps = false

      local x = math.random(10, mapWidth - 20) --TODO make fix magic numbers
      local y = math.random(10, mapHeight - 20)
      local w = math.random(5, 15)
      local h = math.random(5, 15)
      potentialBuilding = { x = x, y = y, width = w, height = h }

      for _, other in ipairs(buildings) do
        if self:overlapRect(potentialBuilding, other) then
          overLaps = true
          break
        end
      end
    end

    table.insert(buildings, potentialBuilding)
    self:makeBuilding(
      potentialBuilding.x,
      potentialBuilding.y,
      potentialBuilding.width,
      potentialBuilding.height,
      math.random(3, mapDepth),
      tiles
    )
  end
end

return city_generator
