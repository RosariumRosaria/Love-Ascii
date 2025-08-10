local config = require("config")
local defaultFont
local tileSize
local render_utils = {}

function render_utils.getHeightLevelScale(i, maxHeight, visible, base)
  local heightFactor = (i + 0.5) / maxHeight
  local alpha = heightFactor * base
  if not visible then
    alpha = alpha * 0.3
  end

  return math.max(math.min(alpha, 2), 0.1)
end

function render_utils.getMaxTextWidth(texts, font)
  local maxWidth = ""
  font = font or defaultFont
  for _, text in ipairs(texts) do
    if font:getWidth(text) > font:getWidth(maxWidth) then
      maxWidth = text
    end
  end
  return font:getWidth(maxWidth)
end

-- Returns the final color to be used based on visibility and exploration
function render_utils.getEffectiveColor(color, visible, explored)
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
function render_utils.scaleColor(color, scale)
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
function render_utils.getScreenCoords(x, y, centerX, centerY)
  local screenX = (x - centerX + love.graphics.getWidth() / tileSize / 2) * tileSize
  local screenY = (y - centerY + love.graphics.getHeight() / tileSize / 2) * tileSize
  return screenX, screenY
end

function render_utils.distanceScale(x1, y1, x2, y2)
  local screenWidth = love.graphics.getWidth()
  local screenHeight = love.graphics.getHeight()

  local tilesWide = screenWidth / tileSize
  local tilesHigh = screenHeight / tileSize

  local maxDist = math.sqrt((tilesWide / 2) ^ 2 + (tilesHigh / 2) ^ 2)
  local dist = math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)

  return math.min(math.max(1 - (dist / maxDist), 0.05), 1)
end

-- Gets a visual offset based on height and offset type
function render_utils.getOffset(i, offsetType, offset, x, y, centerX, centerY)
  if offsetType == 1 then
    local scale = 0.1
    return (i - 1) * offset * (x - centerX) * scale, (i - 1) * offset * (y - centerY) * scale
  elseif offsetType == 2 then
    return -(i - 1) * offset, -(i - 1) * offset
  end
  return 0, 0
end

local GlyphCenterCache = setmetatable({}, { __mode = "k" })

function render_utils.getVisualCenterFromTop(font, ch)
  local perFont = GlyphCenterCache[font]
  if not perFont then
    perFont = {}
    GlyphCenterCache[font] = perFont
  end
  if perFont[ch] then
    return perFont[ch]
  end

  local pad = 4
  local lineH = font:getHeight()
  local w = math.max(8, math.ceil(font:getWidth(ch)) + pad * 2)
  local h = lineH + pad * 2

  local canvas = love.graphics.newCanvas(w, h)
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setFont(font)
  love.graphics.print(ch, pad, pad)
  love.graphics.setCanvas()
  love.graphics.pop()

  local img = canvas:newImageData()
  local top, bottom = h, -1
  for y = 0, h - 1 do
    local rowHasInk = false
    for x = 0, w - 1 do
      local _, _, _, a = img:getPixel(x, y)
      if a > 0 then
        rowHasInk = true
        break
      end
    end
    if rowHasInk then
      if y < top then
        top = y
      end
      if y > bottom then
        bottom = y
      end
    end
  end

  local centerFromTop
  if bottom >= top then
    centerFromTop = (top + bottom) * 0.5 - pad
  else
    centerFromTop = lineH * 0.5
  end

  perFont[ch] = centerFromTop
  return centerFromTop
end

function render_utils.load()
  tileSize = config.tileSize
  defaultFont = config.font
end

return render_utils
