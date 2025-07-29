local map = require("map.map")

local renderer = require("visuals.renderer")
local fov_handler = require("fov.fov_handler")
local entities = require("entities.entities")
local visuals = require("visuals.visuals")
local input_handler = require("engine.input_handler")
local tileSize = 16


function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("Hello World")
    love.window.setMode(0, 0, {resizable = true, vsync = true, fullscreen = true})
    local scale = 2
    local font = love.graphics.newFont("assets/FiraCode-Regular.ttf", 16*scale)
    love.graphics.setFont(font)

    tileSize = love.graphics.getFont():getHeight() 

    local mapWidth = 100
    local mapHeight = 100
    local mapDepth = 7;

    player = {
        char = "@",
        x = 20,
        y = 20,
        z = 1,
        damage = 1
    }

    entities:addEntity(player)
    entities:addFromTemplate("vampire", 5, 5, 1)
    entities:addFromTemplate("crate", 6, 5, 1)

    map:load(mapWidth, mapHeight, mapDepth, "town", tileSize)
    map:updateVisibility(player.x, player.y, 25)
end

timeSinceLastUpdate = 0;
timeBetweenUpdates = 0.1;



function love.update(dt) --Todo: Make movement check key pressed, to avoid the timer
    input_handler:update(dt)
    visuals:update(dt) 
end



function love.draw()
    map:draw(player.x, player.y, 25) --Todo, fix hardcoded draw distance
    for _, entity in ipairs(entities:getEntityList()) do
        if map:isVisible(entity.x, entity.y) then
            renderer:drawEntity(entity.char, tileSize, entity.x, entity.y, player.x, player.y)
        end
    end
end