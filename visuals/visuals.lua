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

function visuals:get_visual_list()
  return self.visualList
end

function visuals:addVisual(visual)
  table.insert(self.visualList, visual)
end

local function deepCopy(tbl)
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

function visuals:add_from_template(name, x, y, z, overrides)
  local template = visualTypes[name]
  if not template then
    error("Entity type '" .. tostring(name) .. "' does not exist")
  end
  local newEntity = deepCopy(template)

  newEntity.x = x or 1
  newEntity.y = y or 1
  newEntity.z = z or 1

  if overrides then
    for k, v in pairs(overrides) do
      newEntity[k] = v
    end
  end

  self:addVisual(newEntity)
  return newEntity
end

local function updateVisualParts(parts, nextFrame)
  local remaining = 0

  for i = #parts, 1, -1 do
    local part = parts[i]
    local maxFrames = part.colors and #part.colors or 1
    if nextFrame > maxFrames then
      table.remove(parts, i)
    else
      remaining = remaining + 1
    end
  end

  return remaining
end

function visuals:update(dt)
  for i = #self.visualList, 1, -1 do
    local visual = self.visualList[i]
    local params = visual.params
    params.lifespan = params.lifespan - dt

    if params.lifespan <= 0 then
      local iNext = params.i + 1
      local totalRemaining = 0

      if visual.rects then
        totalRemaining = totalRemaining + updateVisualParts(visual.rects, iNext)
      end

      if totalRemaining > 0 then
        params.i = iNext
        params.lifespan = params.initialSpan
      else
        table.remove(self.visualList, i)
      end
    end
  end
end

return visuals
