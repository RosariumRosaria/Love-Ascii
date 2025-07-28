local shadowLine = require("map.fov.shadowLine")
local shadow = require("map.fov.shadow")
local entities = require("entities.entities")
local fovutil = {}

local function transformOctant(row, col, octant)
    local dx, dy
    if octant == 0 then dx, dy =  col, -row
    elseif octant == 1 then dx, dy =  row, -col
    elseif octant == 2 then dx, dy =  row,  col
    elseif octant == 3 then dx, dy =  col,  row
    elseif octant == 4 then dx, dy = -col,  row
    elseif octant == 5 then dx, dy = -row,  col
    elseif octant == 6 then dx, dy = -row, -col
    elseif octant == 7 then dx, dy = -col, -row
    else
        error("Invalid octant: " .. tostring(octant))
    end
    return dx, dy
end


function fovutil:paintOctant(playerX, playerY, maxDistance, width, height, mapGrid)
  for row = maxDistance - 1, 1, -1 do
    local line = ""
    for col = 0, row do
      line =  line.."{ "
      local x = playerX + col
      local y = playerY - row
      if  (fovutil:inbounds(y, x, width, height)) then
                  line = line .. mapGrid[y][x][1].char

      line = line .. tostring(mapGrid[y][x][1].transparent)
      end

      line = line .. " }"
    end
    print(line)
  end
end

function fovutil:paintOctantVisiblity(playerX, playerY, maxDistance, width, height, mapGrid, visiblityGrid)
  for row = maxDistance - 1, 1, -1 do
          local line =  " "
    for col = 0, row do

      local x = playerX + col
      local y = playerY - row
      if  (fovutil:inbounds(y, x, width, height) and visiblityGrid[y][x]) then
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

function fovutil:refreshVisibility(playerX, playerY, maxDistance, width, height, mapGrid, visibilityGrid)
  for octant = 0, 7 do
    fovutil:refreshOctant(playerX, playerY, octant, maxDistance, width, height, mapGrid, visibilityGrid)
  end
end

function fovutil:refreshOctant(playerX, playerY, octant, maxDistance, width, height, mapGrid, visibilityGrid)
  local line = shadowLine:new()
  local fullShadow = false
  -- fovutil:paintOctant(playerX, playerY, maxDistance, width, height, mapGrid)
  for row = 1, maxDistance do
    -- Stop once we go out of bounds.
    local dx, dy = transformOctant(row, 0, octant)
    local posX = playerX+dx
    local posY=  playerY+dy

    if not (fovutil:inbounds(posX, posY, width, height)) then
      break
    end

    for col = 0, row do
      dx, dy = transformOctant(row, col, octant)
      posX = playerX+dx
      posY=  playerY+dy

      if not (fovutil:inbounds(posX, posY, width, height)) then
        break
      end

      if (fullShadow) then
        visibilityGrid[posY][posX] = false
      else 
        local projection = shadow.projectTile(row, col)
        
        local visible = not line:isInShadow(projection)
        visibilityGrid[posY][posX] = visible
        if (visible and not mapGrid[posY][posX][1].transparent or entities:getEntity(posX,posY)) then
          line:AddShadow(projection)
          fullShadow = line:isFullShadow()
        end
      end
    end
  end
end

return fovutil