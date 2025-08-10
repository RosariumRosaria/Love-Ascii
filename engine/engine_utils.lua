local entities = require("entities.entities")
local ui_handler = require("visuals.ui_handler")
local map = require("map.map")

local engine_utils = {}

function engine_utils.distanceBetween(entity1, entity2)
  if not entity1 then
    ui_handler:addTextToUIByName("terminal", "entity1 is nil")
  end
  if not entity2 then
    ui_handler:addTextToUIByName("terminal", "entity2 is nil")
  end
  return math.sqrt((entity1.x - entity2.x) ^ 2 + (entity1.y - entity2.y) ^ 2)
end

function engine_utils.isTileFree(x, y, z, skipEntities)
  local entityList = entities:getEntityList()
  if not map:walkable(x, y, z) then
    return false
  end
  for _, ent in ipairs(entityList) do
    if
      not skipEntities[ent]
      and not entities:getTagEntity(ent, "walkable")
      and ent.x == x
      and ent.y == y
      and ent.z == z
    then
      return false
    end
  end
  return true
end

return engine_utils
