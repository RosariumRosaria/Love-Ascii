local map = require("map.map")
local engine = require("engine")
local renderer = require("renderer")
local fovutil = require("map.fov.fovutil")
local entities = require("entities.entities")
local tileSize = 16


function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("Hello World")
    love.window.setMode(0, 0, {resizable = true, vsync = true, fullscreen = true})
    local scale = 2
    local font = love.graphics.newFont("assets/FiraCode-Regular.ttf", 16*scale)
    love.graphics.setFont(font)

    tileSize = love.graphics.getFont():getHeight() 

    local mapWidth = 50
    local mapHeight = 50
    local mapDepth = 7;

    player = {
        char = "@",
        x = 20,
        y = 20,
        z = 1
    }

    entities:addEntity(player)
    entities:addFromTemplate("vampire", 5, 5, 1)
    entities:addFromTemplate("crate", 6, 5, 1)

    map:load(mapWidth, mapHeight, mapDepth, "town", tileSize)
    map:updateVisibility(player.x, player.y, 20)
end

timeSinceLastUpdate = 0;
timeBetweenUpdates = 0.1;

local function getEntity(x, y)
    for _, entity in ipairs(entities) do
        if entity.x == x and entity.y == y then
            print("Found entity at " .. x .. ", " .. y .. ": " .. entity.char)
            return entity
        end
    end

    print("No entity found at " .. x .. ", " .. y)
end

function love.update(dt) --Todo: Make movement check key pressed, to avoid the timer
    local moved = false;
    local moveDir = {x = 0, y = 0}
    if (timeSinceLastUpdate > timeBetweenUpdates) then
        timeSinceLastUpdate = 0;


        if love.keyboard.isDown("left") then
            moveDir.x = -1
            moved = true;
        end
        if love.keyboard.isDown("right") then
            moveDir.x = 1
            moved = true;
        end
        if love.keyboard.isDown("up") then
            moveDir.y = -1
            moved = true
        end
        if love.keyboard.isDown("down") then
            moveDir.y = 1
            moved = true;
        end

        if love.keyboard.isDown("e") then
  
            engine:push(player, moveDir.x, moveDir.y)
            map:updateVisibility(player.x, player.y, 20) -- Todo, fix hardcoded radius
            moved = false
        elseif
            love.keyboard.isDown("q") then
            local target = entities:getEntity(player.x - moveDir.x, player.y - moveDir.y)
            engine:pull(player, moveDir.x, moveDir.y)
            map:updateVisibility(player.x, player.y, 20)
            moved = false
        end

        if love.keyboard.isDown("r") then
               renderer:switchRadial()
        end

    else    
        timeSinceLastUpdate = timeSinceLastUpdate + dt
    end

    if moved then
        engine:move(player, moveDir.x, moveDir.y)
        map:updateVisibility(player.x, player.y, 20) -- Todo, fix hardcoded radius
    end

    if love.keyboard.isDown("escape") then
        love.event.quit()
    end
    if love.keyboard.isDown("z") then
        for i = 1, 255 do
        print()
        end
    end
end



function love.draw()
    map:draw(player.x, player.y, 20) --Todo, fix hardcoded draw distance
    local screenCenterX = love.graphics.getWidth() / tileSize / 2
    local screenCenterY = love.graphics.getHeight() / tileSize / 2
    for _, entity in ipairs(entities:getEntityList()) do
        if map:isVisible(entity.x, entity.y) then
            renderer:drawEntity(entity.char, tileSize, entity.x-player.x+screenCenterX, entity.y-player.y+screenCenterY)
        end
    end
end