local ui_handler = {
  uiList = {},
}

local statusTypes = { "stats", "inventory" }
local statusPos = 1
local statusPanel

function ui_handler:switchStatus()
  statusPos = (statusPos % 2) + 1
  statusPanel.mode = statusTypes[statusPos]
  ui_handler:updateStatus()
end

function ui_handler:getUIList(name)
  return ui_handler.uiList
end

function ui_handler:getScreenCoords(x, y, centerX, centerY, tileSize)
  local screenX = (x - centerX + love.graphics.getWidth() / tileSize / 2) * tileSize
  local screenY = (y - centerY + love.graphics.getHeight() / tileSize / 2) * tileSize
  return screenX, screenY
end

function ui_handler:addUI(x, y, width, height, name, color, outlineWidth, outlinecolor, centerText, tileGrid)
  local ui = {
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
    scrollOffset = 0,
    capacity = height * 10,
  }

  table.insert(ui_handler.uiList, ui)

  return ui
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
  if #ui.texts * textHeight > ui.capacity then
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
  statusPanel =
    ui_handler:addUI(startX, startY, width, screenHeight - height - (4 * buffer), "status", black, outlineWidth, white)
  statusPanel.mode = "inventory"
end

function ui_handler:updateStatus() --TODO, I wonder if there's a way to make this more dynamically describe whatever I pass it. Maybe if I change the describe() funtion by type?
  statusPanel.texts = {}

  if statusPanel.mode == "stats" then
    for statName, stat in pairs(player.stats) do
      local current = stat[statName]
      local max = stat["max" .. statName:gsub("^%l", string.upper)]
      ui_handler:addTextToUIByName("status", statName .. ": " .. current .. " / " .. max)
    end
  elseif statusPanel.mode == "inventory" then
    for itemName, item in pairs(player.inventory) do
      ui_handler:addTextToUIByName("status", "- " .. itemName)
    end
  end
end

return ui_handler
