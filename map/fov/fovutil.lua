local shadowLine = require("map.fov.shadowLine")
local shadow = require("map.fov.shadow")
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


function fovutil:inbounds(x, y, width, height) 
    return x >= 1 and x <= width and y >= 1 and y <= height
end

function fovutil:refreshVisibility(playerX, playerY, maxDistance, width, height, tiles)
  for octant = 0, 7 do
    fovutil:refreshOctant(playerX, playerY, octant, maxDistance, width, height, tiles)
  end
end

function fovutil:refreshOctant(playerX, playerY, octant, maxDistance, width, height, mapGrid, visiblityGrid)
  local line = shadowLine:new()
  local fullShadow = false

  for row = 1, maxDistance do
    -- Stop once we go out of bounds.
    local dx, dy = transformOctant(row, 0, octant)
    local pos = {playerX+dx, playerY +dy};
    if not (fovutil:inbounds(pos[1], pos[2], width, height)) then
      break
    end

    for col = 0, row do
      dx, dy = transformOctant(row, col, octant)
      pos = {playerX+dx, playerY +dy};

      if not (fovutil:inbounds(pos[1], pos[2], width, height)) then
        break
      end

      if (fullShadow) then
        visiblityGrid[pos[2]][pos[1]] = false;
      else 
        print(row, col)
        local projection = shadow.projectTile(row, col)
        
        local visible = not line.isInShadow(projection)
        visiblityGrid[pos[2]][pos[1]] = false
        
        if (visible and mapGrid[pos[2]][pos[1]].transparent) then
          line:AddShadow(projection)
          fullShadow = line:isFullShadow()
        end
      end
    end
  end
end

return fovutil