local map = require("map.map")
local entities = require("entities.entities")
local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local pathfinder = require("engine.pathfinder")
local fov_handler = require("fov.fov_handler")
local engine = require("engine.engine")
local engine_utils = require("engine.engine_utils")

local ai_handler = {}
--TODO, rethink some of this, having the following state be the same for wandering and attacking is fine, but once popups are fixed you'll want to incorporate those

function ai_handler:checkValidTarget(entity, target, state)
  local visible = fov_handler:refreshVisibility(
    entity.x,
    entity.y,
    entity.sight,
    map:getWidth(),
    map:getHeight(),
    map:getTiles(),
    nil,
    false,
    target.x,
    target.y
  )
  local ret = engine_utils:distanceBetween(entity, target) < entity.sight and visible

  if ret then
    entity.turnsToIdle = 25 --TODO: Should different enemies process memory differently?
    entity.targetPos = { target.x, target.y }
    entity.targetEntity = target
    entity.state = state
  end
  return ret
end

local function canSeePlayer(entity)
  entity.canSee = false
  if engine_utils:distanceBetween(entity, player) < entity.sight then
    entity.canSee = fov_handler:refreshVisibility(
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
    )
  end

  if entity.canSee then
    entity.state = "chasing"
    entity.targetEntity = player
    entity.targetPos = { player.x, player.y }
    entity.turnsToIdle = 20
    return true
  end

  return false
end

function ai_handler:idle(entity)
  if entity.type == "enemy" then
    if canSeePlayer(entity) then
      return
    end
    local chance = math.random(1, 5)
    if chance == 1 then
      local tarX = entity.x + math.random(-10, 10)
      local tarY = entity.y + math.random(-10, 10)
      if tarX ~= entity.x or tarY ~= entity.y then
        entity.state = "wandering"
        entity.targetPos = { tarX, tarY }
        entity.turnsToIdle = 20
      end
    elseif chance == 2 or chance == 3 then
      local axis = math.random(1, 2)
      local step = (math.random(0, 1) * 2 - 1)
      local dx = (axis == 1) and step or 0
      local dy = (axis == 2) and step or 0
      engine:move(entity, dx, dy)
    end
  end
end

function ai_handler:wander(entity)
  if entity.type == "enemy" then
    if entity.turnsToIdle and entity.turnsToIdle > 0 and entity.targetPos then
      if canSeePlayer(entity) then
        return
      end

      if entity.x == entity.targetPos[1] and entity.y == entity.targetPos[2] then
        entity.state = "idle"
        entity.targetPos = nil
        return
      end

      entity.path = pathfinder:aStar({ entity.x, entity.y }, entity.targetPos)
      if entity.path then
        local step = entity.path[2]
        if step and step[1] and step[2] then
          local dx = step[1] - entity.x
          local dy = step[2] - entity.y
          engine:move(entity, dx, dy)
        end
      end

      entity.turnsToIdle = entity.turnsToIdle - 1
      if entity.turnsToIdle <= 1 then
        visuals:addFromTemplate("ping", entity.targetPos[1], entity.targetPos[2], 1)
        entity.state = "idle"
        entity.targetPos = nil
      end
    end
  end
end

function ai_handler:chase(entity)
  if entity.turnsToIdle and entity.turnsToIdle > 0 and entity.targetPos then
    if canSeePlayer(entity) then
      entity.path = pathfinder:aStar({ entity.x, entity.y }, entity.targetPos)
      entity.pathIndex = 2
    end

    if entity.path then
      if entity.pathIndex > #entity.path then
        visuals:addFromTemplate("ping", entity.targetPos[1], entity.targetPos[2], 1)
        entity.state = "idle"
        entity.targetPos = nil
        return
      end

      local step = entity.path[entity.pathIndex]
      if step and step[1] and step[2] then
        local dx = step[1] - entity.x
        local dy = step[2] - entity.y
        if engine:move(entity, dx, dy) then
          entity.pathIndex = entity.pathIndex + 1
        end
      end
    end

    entity.turnsToIdle = entity.turnsToIdle - 1
    if entity.turnsToIdle <= 1 then
      visuals:addFromTemplate("ping", entity.targetPos[1], entity.targetPos[2], 1)
      entity.state = "idle"
      entity.targetPos = nil
    end
  end
end

function ai_handler:processEnemy(entity)
  if entity.state == "idle" then
    ai_handler:idle(entity)
  elseif entity.state == "wandering" then
    ai_handler:wander(entity)
  elseif entity.state == "chasing" then
    ai_handler:chase(entity)
  end

  if entity.canSee and not entity.couldSee then
    visuals:addFromTemplate("alert", entity.x, entity.y, entity.z, { anchor = entity })
  end

  entity.couldSee = entity.canSee
end

function ai_handler:processTurn()
  local entityList = entities:getEntityList()
  for _, entity in ipairs(entityList) do
    if entity.type == "enemy" then
      ai_handler:processEnemy(entity)
    end
  end
end

return ai_handler
