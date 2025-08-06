local map = require("map.map")
local entities = require("entities.entities")
local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local pathfinder = require("engine.pathfinder")
local fov_handler = require("fov.fov_handler")
local engine = require("engine.engine")
local engine_utils = require("engine.engine_utils")

local ai_handler = {}

function ai_handler:checkValidTarget(entity, target)
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
    entity.turnsToIdle = 15 --TODO: Should different enemies process memory differently?
    entity.targetPos = { target.x, target.y }
    entity.targetEntity = target
    entity.state = "following"
  end
  return ret
end

function ai_handler:checkPlayer(entity)
  if entity.type == "enemy" then
    ai_handler:checkValidTarget(entity, player)
  end
end

function ai_handler:idle(entity)
  if entity.type == "enemy" then
    local chance = math.random(1, 20)
    if chance == 1 then
      local tarX = math.random(-10, 10)
      local tarY = math.random(-10, 10)
      ai_handler:checkValidTarget(entity, { x = tarX, y = tarY })
    end
  end
end

function ai_handler:wander() end

function ai_handler:follow(entity)
  if entity.turnsToIdle and entity.turnsToIdle > 0 and entity.targetPos then
    local step = pathfinder:aStar({ entity.x, entity.y }, entity.targetPos)
    if step and step[1] and step[2] then
      local dx = step[1] - entity.x
      local dy = step[2] - entity.y
      engine:move(entity, dx, dy)
    end

    entity.turnsToIdle = entity.turnsToIdle - 1
    if entity.turnsToIdle <= 1 then
      visuals:addFromTemplate("ping", entity.targetPos[1], entity.targetPos[2], 1)
      entity.state = "idle"
    end
  end
end

function ai_handler:processTurn()
  local entityList = entities:getEntityList()
  for _, entity in ipairs(entityList) do
    ai_handler:checkPlayer(entity)

    if entity.state == "idle" then
      ai_handler:idle(entity)
    end

    if entity.state == "following" then
      ai_handler:follow(entity)
    end
  end
end

return ai_handler
