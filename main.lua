local map = require("map.map")
local engine = require("engine")
local renderer = require("renderer")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("Hello World")
    love.window.setMode(0, 0, {resizable = true, vsync = true, fullscreen = true})

    local scale = 2
    local font = love.graphics.newFont("assets/FiraCode-Regular.ttf", 16*scale)
    love.graphics.setFont(font)

    tileSize = 0
    tileSize = love.graphics.getFont():getHeight() 


    local mapWidth = 50
    local mapHeight = 50
    local mapDepth = 5;
    map:load(mapWidth, mapHeight, mapDepth, "town", tileSize)


    player = {
        char = "@",
        x = mapWidth / 2,
        y = mapHeight / 2,
        z = 1
    }
    enemy = {
        char = "V",
        x = 10,
        y = 10,
        z= 1
    }
    entities = {player, enemy}


end

timeSinceLastUpdate = 0;
timeBetweenUpdates = 0.1;
function love.update(dt)

    if (timeSinceLastUpdate > timeBetweenUpdates) then
        timeSinceLastUpdate = 0;
        if love.keyboard.isDown("left") then
            engine:move(player, -1, 0, nil, entities)
        end
        if love.keyboard.isDown("right") then
            engine:move(player, 1, 0, nil, entities)
        end
        if love.keyboard.isDown("up") then
            engine:move(player, 0, -1, nil, entities) 
        end
        if love.keyboard.isDown("down") then
            engine:move(player, 0, 1, nil, entities)
        end
        if love.keyboard.isDown("r") then
               render:switchRadial()
        end
    else    
        timeSinceLastUpdate = timeSinceLastUpdate + dt
    end

    if love.keyboard.isDown("escape") then
        love.event.quit()
    end
end



function love.draw()
    map:draw(player.x, player.y, 20) --Todo, fix hardcoded draw distance
    local screenCenterX = love.graphics.getWidth() / tileSize / 2
    local screenCenterY = love.graphics.getHeight() / tileSize / 2
    for _, entity in ipairs(entities) do
        renderer:drawEntity(entity.char, tileSize, entity.x-player.x+screenCenterX, entity.y-player.y+screenCenterY)
    end
end