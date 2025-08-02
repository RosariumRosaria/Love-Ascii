local ui_handler = {
  uiList = {},
}

function ui_handler:getUIList(name)
  return ui_handler.uiList
end

function ui_handler:getScreenCoords(x, y, centerX, centerY, tileSize)
  local screenX = (x - centerX + love.graphics.getWidth() / tileSize / 2) * tileSize
  local screenY = (y - centerY + love.graphics.getHeight() / tileSize / 2) * tileSize
  return screenX, screenY
end

function ui_handler:addUI(x, y, width, height, name, color, outlineWidth, outlinecolor, centerText, tileGrid)
  table.insert(ui_handler.uiList, {
    x = x,
    y = y,
    height = height,
    width = width,
    name = name,
    color = color,
    outlineWidth = outlineWidth,
    outlinecolor = outlinecolor,
    texts = {},
    centerText = centerText,
    tileGrid = tileGrid,
  })
end

function ui_handler:getUI(name)
  for _, ui in ipairs(ui_handler.uiList) do
    if ui.name == name then
      return ui
    end
  end
end

function ui_handler:addTextToUI(ui, text)
  if not ui then
    return false
  end
  table.insert(ui.texts, text)

  local font = love.graphics.getFont()
  local textHeight = font:getHeight()
  if #ui.texts * textHeight > ui.height then
    table.remove(ui.texts, 1)
  end
end

function ui_handler:addTextToUIByName(name, text)
  ui_handler:addTextToUI(ui_handler:getUI(name), text)
end

function ui_handler:load()
  local screenHeight = love.graphics.getHeight()
  local screenWidth = love.graphics.getWidth()
  local outlineWidth = screenWidth / 400
  local buffer = 4 * outlineWidth
  local width = screenWidth / 6
  local startX = screenWidth - width - buffer
  local height = (screenHeight * 4 / 6) - buffer
  local startY = height + (2 * buffer)
  local black = { 0, 0, 0, 0.5 }
  local white = { 1, 1, 1, 0.5 }

  ui_handler:addUI(startX, buffer, width, height, "terminal", black, outlineWidth, white)
  ui_handler:addUI(startX, startY, width, screenHeight - height - (4 * buffer), "status", black, outlineWidth, white)
end

return ui_handler
