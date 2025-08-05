local config = require("config")
local tileSize
local render_utils = require("visuals.render_utils")
local render_primitives = {}

-- Draws a filled rect (with optional outline) in screen coordinates
function render_primitives:drawRect(xScreen, yScreen, width, height, color, outlineWidth, outlineColor, roundedAmount)
  local roundedAmountX = 0
  local roundedAmountY = 0

  if roundedAmount then
    roundedAmountX = width * roundedAmount
    roundedAmountY = height * roundedAmount
  end

  love.graphics.setColor(color)
  love.graphics.rectangle("fill", xScreen, yScreen, width, height, roundedAmountX, roundedAmountY)

  if outlineWidth and outlineColor then
    love.graphics.setLineWidth(outlineWidth)
    love.graphics.setColor(outlineColor)
    love.graphics.rectangle("line", xScreen, yScreen, width, height, roundedAmountX, roundedAmountY)
    love.graphics.setLineWidth(1)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

-- Draws a single character at screen coordinates, with optional color/alpha/outline
function render_primitives:drawChar(
  xScreen,
  yScreen,
  text,
  color,
  alpha,
  outlineColor,
  centered,
  rotation,
  naturalRotation
)
  local font = love.graphics.getFont()
  local textWidth = font:getWidth(text or "")
  local textHeight = font:getHeight(text)

  local dx, dy = 0, 0
  if centered then
    dx = (tileSize - textWidth) / 2
    dy = (tileSize - textHeight) / 2
  end

  -- Apply rotation if specified
  if rotation then
    rotation = math.rad(((rotation or 0) - (naturalRotation or 0)) % 360)

    -- Use love.graphics.newText to enable rotation
    local textObject = love.graphics.newText(font, text)

    love.graphics.push()
    love.graphics.translate(xScreen + dx + textWidth / 2, yScreen + dy + textHeight / 2)
    love.graphics.rotate(rotation)

    if outlineColor then
      love.graphics.setColor(outlineColor)
      love.graphics.draw(textObject, -textWidth / 2 + 1, -textHeight / 2 + 1)
    end

    local r, g, b, a = unpack(color or { 1, 1, 1, 1 })
    love.graphics.setColor(r, g, b, alpha or a)
    love.graphics.draw(textObject, -textWidth / 2, -textHeight / 2)

    love.graphics.pop()
  else
    if outlineColor then
      love.graphics.setColor(outlineColor)
      love.graphics.print(text, xScreen + dx + 1, yScreen + dy + 1)
    end

    local r, g, b, a = unpack(color or { 1, 1, 1, 1 })
    love.graphics.setColor(r, g, b, alpha or a)
    love.graphics.print(text, xScreen + dx, yScreen + dy)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

-- Draws a block of text line-by-line within a bounding box
function render_primitives:drawTextBlock(texts, xScreen, yScreen, width, outline, centerText, color, lineHeight)
  local font = love.graphics.getFont()
  lineHeight = lineHeight or tileSize
  if color then
    love.graphics.setColor(color)
  end

  for i, text in ipairs(texts) do
    local dx = outline * 2
    if centerText then
      dx = dx - (font:getWidth(text) / 2)
    end

    local drawX = xScreen + dx
    local drawY = yScreen + outline + ((i - 1) * lineHeight)

    love.graphics.print(text, drawX, drawY)
  end
end

-- Composite: draws a panel (box + text block inside)
function render_primitives:drawPanel(
  xScreen,
  yScreen,
  width,
  height,
  fillColor,
  outlineWidth,
  outlineColor,
  texts,
  centerText,
  textColor,
  lineHeight,
  centerBox
)
  local xOffset = 0
  if centerBox then
    local font = love.graphics.getFont()
    xOffset = font:getWidth(render_utils:getMaxTextWidth(texts) / 2)
  end

  self:drawRect(xScreen - xOffset, yScreen, width, height, fillColor, outlineWidth, outlineColor)
  self:drawTextBlock(texts, xScreen, yScreen, width, 1, centerText, textColor or { 1, 1, 1, 1 }, lineHeight)
  love.graphics.getFont()
end

function render_primitives:load()
  tileSize = config.tileSize
end

return render_primitives
