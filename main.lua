local map = require("map.map")
local renderer = require("visuals.renderer")
local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local input_handler = require("engine.input_handler")
local fov_handler = require("fov.fov_handler")
local entities = require("entities.entities")
local tileSize = 16


function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("Hello World")
    love.window.setMode(0, 0, {resizable = true, vsync = true, fullscreen = true})
    local scale = 2
    local font = love.graphics.newFont(16*scale)
    love.graphics.setFont(font)

    tileSize = love.graphics.getFont():getHeight() 

    local mapWidth = 100
    local mapHeight = 100
    local mapDepth = 7;

    player = {
        chars = {"@"},
        x = 20,
        y = 20,
        z = 1,
        stats = {        
            health = {health = 10, maxHealth = 10},
            stamina = {stamina = 10, maxStamina = 10},
            hunger = {hunger = 10, maxHunger = 10},
        },  
        damage = 1
    }

    entities:addEntity(player)
    entities:addFromTemplate("vampire", 5, 5, 1)
    entities:addFromTemplate("crate", 6, 5, 1)
    entities:addFromTemplate("barricade", 7, 5, 1)

    map:load(mapWidth, mapHeight, mapDepth, "town", tileSize)
    map:updateVisibility(player.x, player.y, 25)

    ui_handler:load()
end

timeSinceLastUpdate = 0;
timeBetweenUpdates = 0.1;



function love.update(dt) --Todo: Make movement check key pressed, to avoid the timer
    input_handler:update(dt)
    visuals:update(dt) 
end



function love.draw()
    local scale = 2
    local font = love.graphics.newFont(16*scale)
    love.graphics.setFont(font)
    map:draw(player.x, player.y, 50) --Todo, fix hardcoded draw distance
    for _, entity in ipairs(entities:getEntityList()) do
        renderer:drawEntity(entity, tileSize, player.x, player.y, map:isVisible(entity.x, entity.y), map:isExplored(entity.x, entity.y))
    end

    ui_handler:draw(player)
end

