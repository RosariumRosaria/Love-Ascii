local config = require("config")
local tileSize
local render_utils = {}

function render_utils:getHeightLevelScale(i, maxHeight, centerX, centerY, x, y, visible, base)
  local heightFactor = (i + 0.5) / maxHeight
  local alpha = heightFactor * base
  if not visible then
    alpha = alpha * 0.3
  end

  return math.max(math.min(alpha, 2), 0.1)
end

-- Returns the final color to be used based on visibility and exploration
function render_utils:getEffectiveColor(color, visible, explored)
  if visible then
    if color then
      return {
        (color[1] or 1),
        (color[2] or 1),
        (color[3] or 1),
        (color[4] or 1),
      }
    else
      return { 1, 1, 1, 1 }
    end
  elseif explored then
    return { 0.961, 0.871, 0.702, 0.5 } -- fog-of-war color
  end
  return nil
end

-- Takes a color and scales it by a set amount.
-- If no color is provided, defaults to white.
function render_utils:scaleColor(color, scale)
  if color then
    return {
      (color[1] or 1) * scale,
      (color[2] or 1) * scale,
      (color[3] or 1) * scale,
      (color[4] or 1),
    }
  else
    return { 1, 1, 1, 1 }
  end
end

-- Converts XY map to XY screen coordinates based on camera center
function render_utils:getScreenCoords(x, y, centerX, centerY)
  local screenX = (x - centerX + love.graphics.getWidth() / tileSize / 2) * tileSize
  local screenY = (y - centerY + love.graphics.getHeight() / tileSize / 2) * tileSize
  return screenX, screenY
end

-- Gets distance between map positions and returns a normalized alpha value based on screen size
function render_utils:distanceBetween(x1, y1, x2, y2)
  local screenWidth = love.graphics.getWidth()
  local screenHeight = love.graphics.getHeight()

  local tilesWide = screenWidth / tileSize
  local tilesHigh = screenHeight / tileSize

  local maxDist = math.sqrt((tilesWide / 2) ^ 2 + (tilesHigh / 2) ^ 2)
  local dist = math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)

  return math.min(math.max(1 - (dist / maxDist), 0.05), 1)
end

-- Gets a visual offset based on height and offset type
function render_utils:getOffset(i, offsetType, offset, x, y, centerX, centerY)
  if offsetType == 1 then
    local scale = 0.1
    return (i - 1) * offset * (x - centerX) * scale, (i - 1) * offset * (y - centerY) * scale
  elseif offsetType == 2 then
    return -(i - 1) * offset, -(i - 1) * offset
  end
  return 0, 0
end

function render_utils:load()
  tileSize = config.tileSize
end

return render_utils
