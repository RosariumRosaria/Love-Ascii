local entities = require("entities.entities")
local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local engine_utils = require("engine.engine_utils")

local engine = {}

function engine:defaultInteract(entity, dx, dy)
  local target = entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
  if not target then
    return false
  end
  local action = target.defaultAction
  if action == "interactable" and entity.allowedActions[action] then
    return self:interact(entity, dx, dy)
  elseif action == "attackable" and entity.allowedActions[action] then
    return self:attack(entity, dx, dy)
  elseif action == "moveable" and entity.allowedActions[action] then
    return self:push(entity, dx, dy)
  end
  return false
end

local function validateInteraction(actor, target, name)
  if not actor then
    ui_handler:addTextToUIByName("terminal", name .. " actor is nil")
    return false
  end
  if not target then
    ui_handler:addTextToUIByName("terminal", name .. " target is nil")
    return false
  end
  if engine_utils:distanceBetween(actor, target) > 1 then
    ui_handler:addTextToUIByName("terminal", name .. " too far apart")
    return false
  end
  return true
end

function engine:attack(entity, dx, dy)
  local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
  if not validateInteraction(entity, targetEntity, "Attack") then
    return false
  end
  if not entities:getTagEntity(targetEntity, "attackable") then
    ui_handler:addTextToUIByName("terminal", targetEntity.name .. " is not attackable")
    return false
  end
  if entity.type ~= targetEntity.type then
    visuals:addFromTemplate("attack", entity.x + dx, entity.y + dy, entity.z)
    entities:damageEntity(targetEntity, entity)
  end
  return true
end

function engine:interact(entity, dx, dy)
  local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
  if not validateInteraction(entity, targetEntity, "Interact") then
    return false
  end

  if not targetEntity.tags.interactable then
    ui_handler:addTextToUIByName("terminal", "Nothing to do here")
    return false
  end
  entities:interactWithEntity(targetEntity)
  return true
end

function engine:inspect(entity, dx, dy)
  local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
  if not validateInteraction(entity, targetEntity, "Inspect") then
    return false
  end

  entities:inspectEntity(targetEntity)
  deepPrint(targetEntity)
end

function engine:move(entity, dx, dy)
  local tarX = entity.x + dx
  local tarY = entity.y + dy

  if engine_utils:isTileFree(tarX, tarY, entity.z, { [entity] = true }) then
    local visual = visuals:addFromTemplate("trail", entity.x, entity.y, entity.z)
    visual.rects[1].colors[1] = entity.effectColor or visual.rects[1].colors[1]
    entity.x = tarX
    entity.y = tarY
    return true
  end

  return engine:defaultInteract(entity, dx, dy)
end

function engine:grab(entity, dx, dy)
  return entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
end

function engine:push(entity, dx, dy) --TODO Probably some way to integrate pushing and pulling, and to use move
  local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
  if not validateInteraction(entity, targetEntity, "Push") then
    return false
  end

  if not targetEntity.tags.moveable then
    return false
  end

  local pusherTarX = entity.x + dx
  local pusherTarY = entity.y + dy
  local pushedTarX = targetEntity.x + dx
  local pushedTarY = targetEntity.y + dy
  if not engine_utils:isTileFree(pusherTarX, pusherTarY, entity.z, { [entity] = true, [targetEntity] = true }) then
    ui_handler:addTextToUIByName("terminal", "Pusher tile not free")
    return false
  end
  if not engine_utils:isTileFree(pushedTarX, pushedTarY, targetEntity.z, { [targetEntity] = true }) then
    ui_handler:addTextToUIByName("terminal", "Pushed tile not free")
    return false
  end
  visuals:addFromTemplate("trail", entity.x, entity.y, entity.z)
  entity.x = pusherTarX
  entity.y = pusherTarY
  targetEntity.x = pushedTarX
  targetEntity.y = pushedTarY
  ui_handler:addTextToUIByName("terminal", "Pushed " .. targetEntity.name .. " to " .. pushedTarX .. ", " .. pushedTarY)

  return true
end

function engine:pull(entity, dx, dy)
  local targetEntity = entities:getEntity(entity.x - dx, entity.y - dy, entity.z)
  if not validateInteraction(entity, targetEntity, "Pull") then
    return false
  end

  if not targetEntity.tags.moveable then
    return false
  end
  local pullerTarX = entity.x + dx
  local pullerTarY = entity.y + dy
  local pulledTarX = targetEntity.x + dx
  local pulledTarY = targetEntity.y + dy

  if not engine_utils:isTileFree(pullerTarX, pullerTarY, entity.z, { [entity] = true }) then
    ui_handler:addTextToUIByName("terminal", "Puller tile not free")
    return false
  end

  if
    not engine_utils:isTileFree(pulledTarX, pulledTarY, targetEntity.z, { [entity] = true, [targetEntity] = true })
  then
    ui_handler:addTextToUIByName("terminal", "Pulled tile not free")
    return false
  end
  visuals:addFromTemplate("trail", entity.x, entity.y, entity.z)
  entity.x = pullerTarX
  entity.y = pullerTarY
  targetEntity.x = pulledTarX
  targetEntity.y = pulledTarY
  ui_handler:addTextToUIByName("terminal", "Pulled " .. targetEntity.name .. " to " .. pulledTarX .. ", " .. pulledTarY)

  return true
end

return engine
