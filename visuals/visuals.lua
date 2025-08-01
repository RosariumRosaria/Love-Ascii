local visualTypes = require("visuals/visual_types")

local visuals = {
  visualList = {},
  visualTypeDict = {},
}

function visuals:getVisuals(x, y, z)
  local ret = {}
  for _, visual in ipairs(self.visualList) do
    if visual.x == x and visual.y == y and visual.z == z then
      table.insert(ret, visual)
    end
  end
  return ret
end

function visuals:getVisualList()
  return self.visualList
end

function visuals:addVisual(visual)
  if visual.type == "popup" then
    self:describe(visual, 1)
    local font = love.graphics.getFont()
    local textHeight = font:getHeight()
    local offset = textHeight
  end
  table.insert(self.visualList, visual)
end

function deepCopy(tbl)
  local copy = {}
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      copy[k] = deepCopy(v) -- Recursively copy tables
    else
      copy[k] = v
    end
  end
  return copy
end

function visuals:addFromTemplate(name, x, y, z)
  local template = visualTypes[name]
  if not template then
    error("Visual type '" .. tostring(name) .. "' does not exist")
  end

  local newVisual = {}

  -- Use deepCopy to preserve the structure of subtables
  for k, v in pairs(template) do
    if type(v) == "table" then
      newVisual[k] = deepCopy(v) -- Make a proper copy of nested tables
    else
      newVisual[k] = v
    end
  end

  newVisual.x = x or 1
  newVisual.y = y or 1
  newVisual.z = z or 1

  self:addVisual(newVisual)
  return newVisual
end

function visuals:update(dt)
  for i = #self.visualList, 1, -1 do
    local visual = self.visualList[i]
    visual.lifespan = visual.lifespan - dt
    if visual.lifespan <= 0 then
      if visual.colors then
        if #visual.colors > visual.i then
          visual.i = visual.i + 1
          visual.lifespan = visual.initialSpan
        else
          table.remove(self.visualList, i)
        end
      else
        table.remove(self.visualList, i)
      end
    end
  end
end

return visuals
