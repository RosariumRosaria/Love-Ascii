local map = require("map.map")
local entities = require("entities.entities")
local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local pathfinder = require("engine.pathfinder")
local fov_handler = require("fov.fov_handler")
local engine = {}

local function distanceBetween(entity1, entity2)
  if not entity1 then
    ui_handler:addTextToUIByName("terminal", "entity1 is nil")
  end
  if not entity2 then
    ui_handler:addTextToUIByName("terminal", "entity2 is nil")
  end
  return math.sqrt((entity1.x - entity2.x) ^ 2 + (entity1.y - entity2.y) ^ 2)
end

local function isTileFree(x, y, z, skipEntities) --Maybe we can seperate this and other helpers into a more generic util module. Too much logic is being done here
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

function engine:attack(entity, dx, dy)
  local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
  if not entity then
    ui_handler:addTextToUIByName("terminal", "Attacking entity is nil")
    return false
  end
  if not targetEntity then
    ui_handler:addTextToUIByName("terminal", "Attacked entity is nil")
    return false
  end
  if distanceBetween(entity, targetEntity) > 1 then
    ui_handler:addTextToUIByName("terminal", "Too far apart")
    return false
  end
  if not entities:getTagEntity(targetEntity, "attackable") then
    ui_handler:addTextToUIByName("terminal", targetEntity.name .. " is not attackable")
    return false
  end
  visuals:addFromTemplate("attack", entity.x + dx, entity.y + dy, entity.z)
  entities:damageEntity(targetEntity, entity.damage)
  return true
end

function engine:interact(entity, dx, dy)
  local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
  if not entity then
    ui_handler:addTextToUIByName("terminal", "Interacting entity is nil")
    return false
  end
  if not targetEntity then
    ui_handler:addTextToUIByName("terminal", "Interacted entity is nil")
    return false
  end
  if distanceBetween(entity, targetEntity) > 1 then
    ui_handler:addTextToUIByName("terminal", "Too far apart")
    return false
  end
  if not targetEntity.tags.interactable then
    ui_handler:addTextToUIByName("terminal", "Nothing to do here")
    return false
  end
  entities:interactWithEntity(targetEntity)
end

function engine:inspect(entity, dx, dy)
  local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
  if not entity then
    ui_handler:addTextToUIByName("terminal", "Inspecting entity is nil")
    return false
  end
  if not targetEntity then
    ui_handler:addTextToUIByName("terminal", "Inspected entity is nil")
    return false
  end
  if distanceBetween(entity, targetEntity) > 1 then
    ui_handler:addTextToUIByName("terminal", "Too far apart")
    return false
  end

  entities:inspectEntity(targetEntity)
  deepPrint(targetEntity)
end

function engine:move(entity, dx, dy)
  local tarX = entity.x + dx
  local tarY = entity.y + dy
  if isTileFree(tarX, tarY, entity.z, { [entity] = true }) then
    visuals:addFromTemplate("trail", entity.x, entity.y, entity.z)
    entity.x = tarX
    entity.y = tarY
    return true
  end

  return false
end

function engine:grab(entity, dx, dy)
  return entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
end

function engine:push(entity, dx, dy) --TODO Probably some way to integrate pushing and pulling, and to use move
  local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy, entity.z)
  if not entity then
    ui_handler:addTextToUIByName("terminal", "Pusher entity is nil")
    return false
  end
  if not targetEntity then
    ui_handler:addTextToUIByName("terminal", "Pushed entity is nil")
    return false
  end
  if distanceBetween(entity, targetEntity) > 1 then
    ui_handler:addTextToUIByName("terminal", "Pusher and pushed entities are too far apart")
    return false
  end
  if not targetEntity.tags.moveable then
    ui_handler:addTextToUIByName("terminal", "Pushed entity is not moveable")
    return false
  end

  local pusherTarX = entity.x + dx
  local pusherTarY = entity.y + dy
  local pushedTarX = targetEntity.x + dx
  local pushedTarY = targetEntity.y + dy
  if not isTileFree(pusherTarX, pusherTarY, entity.z, { [entity] = true, [targetEntity] = true }) then
    ui_handler:addTextToUIByName("terminal", "Pusher tile not free")
    return false
  end
  if not isTileFree(pushedTarX, pushedTarY, targetEntity.z, { [targetEntity] = true }) then
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
  if not entity then
    ui_handler:addTextToUIByName("terminal", "Puller entity is nil")
    return false
  end
  if not targetEntity then
    ui_handler:addTextToUIByName("terminal", "Pulled entity is nil")
    return false
  end
  if distanceBetween(entity, targetEntity) > 1 then
    ui_handler:addTextToUIByName("terminal", "Puller and Pulled entities are too far apart")
    return false
  end
  if not targetEntity.tags.moveable then
    ui_handler:addTextToUIByName("terminal", "Pulled entity is not moveable")
    return false
  end

  local pullerTarX = entity.x + dx
  local pullerTarY = entity.y + dy
  local pulledTarX = targetEntity.x + dx
  local pulledTarY = targetEntity.y + dy

  if not isTileFree(pullerTarX, pullerTarY, entity.z, { [entity] = true }) then
    ui_handler:addTextToUIByName("terminal", "Puller tile not free")
    return false
  end

  if not isTileFree(pulledTarX, pulledTarY, targetEntity.z, { [entity] = true, [targetEntity] = true }) then
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

function engine:processTurn()
  local entityList = entities:getEntityList()
  for _, entity in ipairs(entityList) do
    if entity.type == "enemy" then
      local visible = fov_handler:refreshVisibility(
        entity.x,
        entity.y,
        entity.sight,
        map:getWidth(),
        map:getHeight(),
        map:getTiles(),
        nil,
        false,
        player.x,
        player.y
      ) --TODO All of this needs to live somewhere else

      if distanceBetween(entity, player) < entity.sight and visible then
        local step = pathfinder:aStar({ entity.x, entity.y }, { player.x, player.y })
        if step and step[1] and step[2] then
          local dx = step[1] - entity.x
          local dy = step[2] - entity.y
          engine:move(entity, dx, dy)
          entity.turnsToIdle = 20
          entity.target = { player.x, player.y }
          if entity.state == "idle" then
            visuals:addFromTemplate("alert", entity.x, entity.y, entity.z, { anchor = entity })
            entity.state = "following"
          end
        end
      elseif entity.turnsToIdle and entity.turnsToIdle > 0 and entity.target then
        if entity.turnsToIdle > 15 then
          entity.target = { player.x, player.y }
        end --TODO make this more dynamic

        local step = pathfinder:aStar({ entity.x, entity.y }, entity.target)
        if step and step[1] and step[2] then
          local dx = step[1] - entity.x
          local dy = step[2] - entity.y
          engine:move(entity, dx, dy)
          visuals:addFromTemplate("ping", entity.target[1], entity.target[2], 1)
          entity.turnsToIdle = entity.turnsToIdle - 1
          if entity.turnsToIdle == 0 then
            entity.state = "idle"
          end
        end
      end
    end
  end

  ui_handler:updateStatus()
end

return engine
