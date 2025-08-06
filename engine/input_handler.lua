local engine = require("engine.engine")
local map = require("map.map")
local render_handler = require("visuals.render_handler")
local ui_handler = require("visuals.ui_handler")
local ai_handler = require("engine.ai_handler")
local input_handler = {}

local timeSinceLastUpdate = 0
local timeBetweenUpdates = 0.125
local lastTurn = { x = 0, y = 0 }
local grabbed = nil

function input_handler:update(dt)
  timeSinceLastUpdate = timeSinceLastUpdate + dt
  if timeSinceLastUpdate < timeBetweenUpdates then
    return
  end
  timeSinceLastUpdate = 0
  local tookAction = false
  local moveDir = { x = 0, y = 0 }

  if love.keyboard.isDown("left") then
    moveDir.x = -1
  elseif love.keyboard.isDown("right") then
    moveDir.x = 1
  elseif love.keyboard.isDown("up") then
    moveDir.y = -1
  elseif love.keyboard.isDown("down") then
    moveDir.y = 1
  end

  local isMoving = moveDir.x ~= 0 or moveDir.y ~= 0
  local hasMoved = lastTurn.x ~= 0 or lastTurn.y ~= 0
  if isMoving or hasMoved then
    if not isMoving then
      moveDir = lastTurn
    end
    if love.keyboard.isDown("f") then
      tookAction = engine:attack(player, moveDir.x, moveDir.y)
    elseif love.keyboard.isDown("e") then
      tookAction = engine:interact(player, moveDir.x, moveDir.y)
    elseif love.keyboard.isDown("r") then
      engine:inspect(player, moveDir.x, moveDir.y)
    elseif isMoving then
      if love.keyboard.isDown("q") then
        if not grabbed then
          grabbed = engine:grab(player, moveDir.x, moveDir.y) or grabbed
        end
        if grabbed then
          if player.x == grabbed.x + moveDir.x and player.y == grabbed.y + moveDir.y then
            tookAction = engine:pull(player, moveDir.x, moveDir.y)
          elseif player.x + moveDir.x == grabbed.x and player.y + moveDir.y == grabbed.y then
            tookAction = engine:push(player, moveDir.x, moveDir.y)
          end
        end
      else
        grabbed = false
        tookAction = engine:move(player, moveDir.x, moveDir.y)
      end
    end
    map:updateVisibility(player.x, player.y, 30) --TODO, why do you live in input handler? And magic number...
    lastTurn = moveDir
  end

  if love.keyboard.isDown("z") then
    render_handler:switchOffset()
  end

  if love.keyboard.isDown("x") then
    ui_handler:switchStatus()
  end

  if love.keyboard.isDown("escape") then
    love.event.quit()
  end

  if tookAction then
    ai_handler:processTurn()
    ui_handler:updateStatus()
  end
end

function love.wheelmoved(_, y)
  local term = ui_handler:getUI("terminal")
  if term then
    term.scrollOffset = math.max(0, term.scrollOffset - y)
  end
end

return input_handler
