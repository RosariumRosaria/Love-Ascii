local shadowLine = require("fov.shadow_line")
local shadow = require("fov.shadow")
local entities = require("entities.entities")
local fovutil = {}

local function transformOctant(row, col, octant)
  local dx, dy
  if octant == 0 then
    dx, dy = col, -row
  elseif octant == 1 then
    dx, dy = row, -col
  elseif octant == 2 then
    dx, dy = row, col
  elseif octant == 3 then
    dx, dy = col, row
  elseif octant == 4 then
    dx, dy = -col, row
  elseif octant == 5 then
    dx, dy = -row, col
  elseif octant == 6 then
    dx, dy = -row, -col
  elseif octant == 7 then
    dx, dy = -col, -row
  else
    error("Invalid octant: " .. tostring(octant))
  end
  return dx, dy
end

function fovutil:paintOctant(entityX, entityY, maxDistance, width, height, mapGrid)
  for row = maxDistance - 1, 1, -1 do
    local line = ""
    for col = 0, row do
      line = line .. "{ "
      local x = entityX + col
      local y = entityY - row
      if fovutil:inbounds(y, x, width, height) then
        line = line .. mapGrid[y][x][1].char

        line = line .. tostring(mapGrid[y][x][1].transparent)
      end

      line = line .. " }"
    end
    print(line)
  end
end

function fovutil:paintOctantVisiblity(entityX, entityY, maxDistance, width, height, mapGrid, visiblityGrid)
  for row = maxDistance - 1, 1, -1 do
    local line = " "
    for col = 0, row do
      local x = entityX + col
      local y = entityY - row
      if fovutil:inbounds(y, x, width, height) and visiblityGrid[y][x] then
        line = line .. mapGrid[y][x][1].char .. " "
      else
        line = line .. "  "
      end
    end
    print(line)
  end
  print("@")
end

function fovutil:inbounds(x, y, width, height)
  return x >= 1 and x <= width and y >= 1 and y <= height
end

function fovutil:refreshVisibility(
  entityX,
  entityY,
  maxDistance,
  width,
  height,
  mapGrid,
  visibilityGrid,
  player,
  targetX,
  targetY
)
  if player then
    visibilityGrid[entityY][entityX] = true
  end
  for octant = 0, 7 do
    local visible = fovutil:refreshOctant(
      entityX,
      entityY,
      octant,
      maxDistance,
      width,
      height,
      mapGrid,
      visibilityGrid,
      player,
      targetX,
      targetY
    ) --TODO check if this works really for enemies
    if visible then
      return true
    end
  end
  return false
end

function fovutil:refreshOctant(
  entityX,
  entityY,
  octant,
  maxDistance,
  width,
  height,
  mapGrid,
  visibilityGrid,
  player,
  targetX,
  targetY
)
  local line = shadowLine:new()
  local fullShadow = false

  -- fovutil:paintOctant(entityX, entityY, maxDistance, width, height, mapGrid)
  for row = 1, maxDistance do
    -- Stop once we go out of bounds.
    local dx, dy = transformOctant(row, 0, octant)
    local posX = entityX + dx
    local posY = entityY + dy

    if not (fovutil:inbounds(posX, posY, width, height)) then
      break
    end

    for col = 0, row do
      dx, dy = transformOctant(row, col, octant)
      posX = entityX + dx
      posY = entityY + dy

      if not (fovutil:inbounds(posX, posY, width, height)) then
        break
      end

      if fullShadow then
        if player then
          visibilityGrid[posY][posX] = false
        elseif posX == targetX and posY == targetY then
          return false
        end
      else
        local projection = shadow.projectTile(row, col)
        local visible = not line:isInShadow(projection)
        if player then
          visibilityGrid[posY][posX] = visible
        elseif posX == targetX and posY == targetY then
          return visible
        end

        local transparent = true
        if #mapGrid[posY][posX] > 1 then
          transparent = mapGrid[posY][posX][2].transparent
        end
        if visible and (not transparent or entities:getTagLocation(posX, posY, 1, "solid")) then
          line:AddShadow(projection)
          fullShadow = line:isFullShadow()
        end
      end
    end
  end
end

return fovutil
