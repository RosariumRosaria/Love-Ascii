local engine = require("engine.engine")
local map = require("map.map")
local entities = require("entities.entities")
local renderer = require("visuals.renderer")

local input_handler = {}

local timeSinceLastUpdate = 0
local timeBetweenUpdates = 0.1

function input_handler:update(dt) --
    timeSinceLastUpdate = timeSinceLastUpdate + dt
    if timeSinceLastUpdate < timeBetweenUpdates then return end
    timeSinceLastUpdate = 0

    local moveDir = { x = 0, y = 0 }

    if love.keyboard.isDown("left") then moveDir.x = -1 end
    if love.keyboard.isDown("right") then moveDir.x = 1 end
    if love.keyboard.isDown("up") then moveDir.y = -1 end
    if love.keyboard.isDown("down") then moveDir.y = 1 end

    local isMoving = moveDir.x ~= 0 or moveDir.y ~= 0

    if isMoving then
        if love.keyboard.isDown("e") then
            engine:push(player, moveDir.x, moveDir.y)
        elseif love.keyboard.isDown("q") then
            engine:pull(player, moveDir.x, moveDir.y)
        else
            engine:move(player, moveDir.x, moveDir.y)
        end
        map:updateVisibility(player.x, player.y, 20)
    end

    if love.keyboard.isDown("r") then
        renderer:switchRadial()
    end

    if love.keyboard.isDown("escape") then
        love.event.quit()
    end
end

return input_handler
