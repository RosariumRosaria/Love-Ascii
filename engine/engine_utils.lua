local entities = require("entities.entities")
local ui_handler = require("visuals.ui_handler")
local map = require("map.map")

local engine_utils = {}

function engine_utils.distance_between(entity1, entity2)
  if not entity1 then
    ui_handler:add_text_to_ui_by_name("terminal", "entity1 is nil")
  end
  if not entity2 then
    ui_handler:add_text_to_ui_by_name("terminal", "entity2 is nil")
  end
  return math.sqrt((entity1.x - entity2.x) ^ 2 + (entity1.y - entity2.y) ^ 2)
end

function engine_utils.is_tile_free(x, y, z, skip_entities)
  local entity_list = entities:get_entity_list()
  if not map:walkable(x, y, z) then
    return false
  end
  for _, ent in ipairs(entity_list) do
    if
      not skip_entities[ent]
      and not entities:get_tag_entity(ent, "walkable")
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
