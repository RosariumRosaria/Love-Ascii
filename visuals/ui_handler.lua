local config = require("config")

local smallTileSize

local ui_handler = {
  uiList = {},
}

local statusTypes = { "stats", "inventory" }
local statusPos = 1
local statusPanel

local function addTextToUI(ui, text)
  if not ui then
    return false
  end
  table.insert(ui.texts, text)

  if #ui.texts > ui.capacity then
    table.remove(ui.texts, 1)
  end
end

function ui_handler:switchStatus()
  statusPos = (statusPos % 2) + 1
  statusPanel.mode = statusTypes[statusPos]
  self:updateStatus()
end

function ui_handler:getUIList()
  return self.uiList
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
    capacity = math.floor(height / smallTileSize) * 10,
  }

  table.insert(self.uiList, ui)

  return ui
end

function ui_handler:getUI(name)
  for _, ui in ipairs(self.uiList) do
    if ui.name == name then
      return ui
    end
  end
end

function ui_handler:addTextToUIByName(name, text)
  addTextToUI(self:getUI(name), text)
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

  smallTileSize = config.smallTileSize

  self:addUI(startX, buffer, width, height, "terminal", black, outlineWidth, white)
  statusPanel =
    self:addUI(startX, startY, width, screenHeight - height - (4 * buffer), "status", black, outlineWidth, white)
  statusPanel.mode = "inventory"
end

function ui_handler:updateStatus()
  statusPanel.texts = {}

  if statusPanel.mode == "stats" then
    for statName, stat in pairs(player.stats) do
      local current = stat[statName]
      local max = stat["max" .. statName:gsub("^%l", string.upper)]
      self:addTextToUIByName("status", statName .. ": " .. current .. " / " .. max)
    end
  elseif statusPanel.mode == "inventory" then
    for itemName, _ in pairs(player.inventory) do
      self:addTextToUIByName("status", "- " .. itemName)
    end
  end
end

return ui_handler
