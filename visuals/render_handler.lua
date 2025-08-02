local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local entities = require("entities.entities")
local render_utils = require("visuals.render_utils")
local map = require("map.map")
local render_primitives = require("visuals.render_primitives")

local render_handler = {}
local config = require("config")
local tileSize
local smallTileSize
local defaultFont
local smallFont

local MAX_HEIGHT = 5 --TODO whys is this here. Fine for now.
local OFFSET_TYPE = 1 -- global rendering style setting
local OFFSET_AMOUNT

function render_handler:switchOffset()
  OFFSET_TYPE = (OFFSET_TYPE % 3) + 1
end

function render_handler:drawVisual(visual, centerX, centerY)
  local xScreen, yScreen = render_utils:getScreenCoords(visual.x, visual.y, centerX, centerY)

  local color = { 1, 1, 1, 1 }

  if visual.rects then
    for _, rect in ipairs(visual.rects) do
      if visual.params.decayOverTime then
        color = render_utils:scaleColor(rect.colors[1], visual.params.lifespan / visual.params.initialSpan)
      else
        color = rect.colors[visual.params.i]
      end
      local visualSize = rect.sizes[visual.params.i] * tileSize
      render_primitives:drawRect(
        xScreen + ((tileSize - visualSize) / 2),
        yScreen + ((tileSize - visualSize) / 2),
        visualSize,
        visualSize,
        color,
        rect.outlineWidth,
        rect.outlineColor,
        rect.roundedAmount
      )
    end
  end
end

function render_handler:drawStack(tile, x, y, z, centerX, centerY, visible, explored)
  --TODO, unify entities and tiles into a stack
end

function render_handler:drawEntity(entity, centerX, centerY, visible, explored)
  local tilelike = entities:getTagEntity(entity, "tilelike")

  if not visible and (not tilelike or not explored) then
    return
  end

  local baseColor = entity.color

  if tilelike then
    baseColor = render_utils:getEffectiveColor(baseColor, visible, explored)
  end

  local xScreen, yScreen = render_utils:getScreenCoords(entity.x, entity.y, centerX, centerY)
  local base = render_utils:distanceBetween(entity.x, entity.y, centerX, centerY)

  for i, charData in ipairs(entity.chars) do
    local scale = render_utils:getHeightLevelScale(
      entity.z + i,
      MAX_HEIGHT,
      centerX,
      centerY,
      entity.x,
      entity.y,
      visible,
      base
    ) + 0.3
    local scaledColor = render_utils:scaleColor(baseColor, scale)
    local dx, dy =
      render_utils:getOffset(entity.z + i - 1, OFFSET_TYPE, OFFSET_AMOUNT, entity.x, entity.y, centerX, centerY)
    render_primitives:drawChar(
      xScreen + dx,
      yScreen + dy,
      charData,
      scaledColor,
      nil,
      entity.outlineColor,
      true,
      entity.rotation,
      entity.naturalRotation
    )
  end
end

function render_handler:drawTile(tileData, x, y, centerX, centerY, visible, explored)
  if not visible and not explored then
    return
  end

  local xScreen, yScreen = render_utils:getScreenCoords(x, y, centerX, centerY)

  local base = render_utils:distanceBetween(x, y, centerX, centerY) + 0.3

  for i, tile in ipairs(tileData) do
    local char = tile.chars[1]
    local alpha = render_utils:getHeightLevelScale(i, MAX_HEIGHT, centerX, centerY, x, y, visible, base)
    local baseColor = render_utils:getEffectiveColor(tile.color, visible, explored)
    if baseColor and (not visible or not entities:getTagLocation(x, y, i, "blocks")) then
      local scaledColor = render_utils:scaleColor(baseColor, alpha)
      local dx, dy = render_utils:getOffset(i, OFFSET_TYPE, OFFSET_AMOUNT, x, y, centerX, centerY)
      render_primitives:drawChar(xScreen + dx, yScreen + dy, char, scaledColor, nil, tile.outlineColor, true)
    end
  end
end

function render_handler:drawUI(ui, smallTileSize)
  local maxLines = math.floor(ui.height / smallTileSize)
  local totalLines = #ui.texts

  ui.scrollOffset = math.max(0, math.min(ui.scrollOffset, math.max(0, totalLines - maxLines)))

  local startLine = math.max(1, totalLines - ui.scrollOffset - maxLines + 1)
  local endLine = math.min(totalLines, startLine + maxLines - 1)

  local visibleTexts = {}
  for i = startLine, endLine do
    table.insert(visibleTexts, ui.texts[i])
  end

  render_primitives:drawPanel(
    ui.x,
    ui.y,
    ui.width,
    ui.height,
    ui.color,
    ui.outlineWidth,
    ui.outlinecolor,
    visibleTexts,
    ui.centerText,
    { 1, 1, 1, 1 },
    smallTileSize
  )
end

function render_handler:draw(centerX, centerY)
  local drawDist = 50 --TODO MAGIC

  --Draw Map
  local endX = math.min(centerX + drawDist, map:getWidth())
  local endY = math.min(centerY + drawDist, map:getHeight())
  local startX = math.max(centerX - drawDist, 1)
  local startY = math.max(centerY - drawDist, 1)
  local tiles = map:getTiles()

  --Draw Entities
  for _, entity in ipairs(entities:getEntityList()) do
    render_handler:drawEntity(
      entity,
      centerX,
      centerY,
      map:isVisible(entity.x, entity.y),
      map:isExplored(entity.x, entity.y)
    )
  end

  for y = startY, endY do
    for x = startX, endX do
      local screenX, screenY = render_utils:getScreenCoords(x, y, centerX, centerY)
      --Temporary for debugging.
      if OFFSET_TYPE == 3 then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.1)
        love.graphics.rectangle("line", screenX, screenY, tileSize, tileSize)
        love.graphics.setColor(1, 1, 1, 1)
      end

      render_handler:drawTile(tiles[y][x], x, y, centerX, centerY, map:isVisible(x, y), map:isExplored(x, y))
    end
  end

  --Draw Visuals
  for _, visual in ipairs(visuals:getVisualList()) do
    render_handler:drawVisual(visual, centerX, centerY)
  end

  --TODO: Is there a better way to know what font I should be using?
  love.graphics.setFont(smallFont)
  for _, ui in ipairs(ui_handler:getUIList()) do
    render_handler:drawUI(ui, smallTileSize)
  end
  love.graphics.setFont(defaultFont)
end

function render_handler:load()
  tileSize = config.tileSize
  smallTileSize = config.smallTileSize
  defaultFont = config.font
  smallFont = config.smallFont

  MAX_HEIGHT = 5
  OFFSET_TYPE = 1
  OFFSET_AMOUNT = 0.25 * tileSize
  render_utils:load()
  render_primitives:load()
end

return render_handler
