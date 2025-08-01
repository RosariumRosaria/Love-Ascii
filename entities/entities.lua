local entityTypes = require("entities/entity_types")
local ui_handler = require("visuals.ui_handler")

local entities = {
  entityList = {},
  entitiesByZ = {},
}

function entities:getTagLocation(x, y, z, tag)
  local entity = entities:getEntity(x, y, z or 1)
  if not entity then
    return false
  end

  return entities:getTagEntity(entity, tag)
end

function entities:getTagEntity(entity, tag)
  return entity.tags[tag]
end

function entities:damageEntity(entity, damage)
  if not entity or not entity.stats or not entity.stats.health then
    return false
  end

  entity.stats.health.health = entity.stats.health.health - damage
  local name = entity.name or "Unnamed"
  ui_handler:addTextToUIByName("terminal", "You hit " .. name .. ": " .. entity.stats.health.health .. " HP remaining!")

  if entity.stats.health.health <= 0 then
    entities:removeEntity(entity)
  end
end

function entities:interactWithEntity(entity)
  local interaction = entity.interaction
  if not interaction then
    return
  end

  for k, v in pairs(interaction) do
    if k == "tags" and type(v) == "table" and type(entity[k]) == "table" then
      for tagKey, tagVal in pairs(v) do
        local oldVal = entity[k][tagKey]
        entity[k][tagKey] = tagVal
        interaction[k][tagKey] = oldVal
      end
    else
      entity[k], interaction[k] = v, entity[k]
    end
  end
end

function entities:inspectEntity(entity)
  if entity.description then
    ui_handler:addTextToUIByName("terminal", entity.description)
  end
end

function entities:getEntity(x, y, z)
  for _, entity in ipairs(self.entityList) do
    if entity.x == x and entity.y == y and entity.z == z then
      return entity
    end
  end
end

function entities:removeEntity(target)
  for i, entity in ipairs(self.entityList) do
    if entity == target then
      table.remove(self.entityList, i)
      break
    end
  end

  local zList = self.entitiesByZ[target.z]
  if zList then
    for i, entity in ipairs(zList) do
      if entity == target then
        table.remove(zList, i)
        break
      end
    end

    if #zList == 0 then
      self.entitiesByZ[target.z] = nil
    end
  end

  return true
end

function entities:getEntityListAtZLevel(z)
  return self.entitiesByZ[z] or {}
end

function entities:getEntityList()
  return self.entityList
end

function entities:addEntity(entity)
  table.insert(self.entityList, entity)

  local z = entity.z

  if not self.entitiesByZ[z] then
    self.entitiesByZ[z] = {}
  end

  table.insert(self.entitiesByZ[z], entity)
end

local function deepCopy(tbl)
  local copy = {}
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      copy[k] = deepCopy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

function entities:addFromTemplate(name, x, y, z, overrides)
  local template = entityTypes[name]
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

  self:addEntity(newEntity)
  return newEntity
end

function entities:describe(entity)
  if not entity then
    ui_handler:addTextToUIByName("terminal", "Entity is nil!")
    return false
  end
  for k, v in pairs(entity) do
    ui_handler:addTextToUIByName("terminal", "key: " .. tostring(k) .. "value: " .. tostring(v))
  end
end

return entities
