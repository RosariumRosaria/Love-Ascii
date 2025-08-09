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
    love.graphics.rectangle(
      "line",
      xScreen - outlineWidth,
      yScreen - outlineWidth,
      width + outlineWidth,
      height + outlineWidth,
      roundedAmountX,
      roundedAmountY
    )
    love.graphics.setLineWidth(1)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function render_primitives:drawChar(xScreen, yScreen, text, color, outlineColor, rotation, naturalRotation)
  if not text or text == "" then
    return
  end

  local font = love.graphics.getFont()
  local textWidth = font:getWidth(text)

  local centerFromTop = render_utils:getVisualCenterFromTop(font, text)

  local cx = xScreen + tileSize * 0.5
  local cy = yScreen + tileSize * 0.5

  local rads = math.rad(((rotation or 0) - (naturalRotation or 0)) % 360)

  local ox = textWidth * 0.5
  local oy = centerFromTop

  if outlineColor then
    love.graphics.setColor(outlineColor)
    love.graphics.print(text, cx + 1, cy + 1, rads, 1, 1, ox, oy)
  end

  love.graphics.setColor(color)
  love.graphics.print(text, cx, cy, rads, 1, 1, ox, oy)

  love.graphics.setColor(1, 1, 1, 1)
end

--Draws a block
function render_primitives:drawTextBlock(texts, xScreen, yScreen, width, outline, centerText, color, lineHeight)
  local font = love.graphics.getFont()
  lineHeight = lineHeight or tileSize
  if color then
    love.graphics.setColor(color)
  end

  for i, text in ipairs(texts) do
    local dx = 0
    if centerText then
      dx = dx + (width - font:getWidth(text)) / 2
    end

    local drawX = xScreen + dx
    local drawY = yScreen + outline + ((i - 1) * lineHeight)

    love.graphics.print(text, drawX, drawY)
  end
end

-- Draws a panel, just calls the rect and textBlock functions
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
  lineHeight
)
  self:drawRect(xScreen, yScreen, width, height, fillColor, outlineWidth, outlineColor)
  self:drawTextBlock(texts, xScreen, yScreen, width, 1, centerText, textColor or { 1, 1, 1, 1 }, lineHeight)
end

function render_primitives:load()
  tileSize = config.tileSize
end

return render_primitives
