require("map")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")


    love.window.setTitle("Hello World")
    love.window.setMode(800, 600, {resizable = true, vsync = true})

    tilesize = 32
    map:load(10, 10, tilesize, "dungeon") -- Initialize the map


    player = {
        char = "@",
        x = 0,
        y = 0
    }


    enemy = {
        char = "E",
        x = 10,
        y = 10
    }
    entities = {player, enemy}


end

function love.keypressed(key)
    if key == "left" then
        player.x = player.x - 1
    elseif key == "right" then
        player.x = player.x + 1
    elseif key == "up" then
        player.y = player.y - 1
    elseif key == "down" then
        player.y = player.y + 1
    elseif key == "escape" then
        love.event.quit()
    end
end

function love.draw()
    map:draw()
    for _, entity in ipairs(entities) do
        love.graphics.print(entity.char, entity.x*tilesize+(tilesize/2), entity.y*tilesize+(tilesize/2))
    end

end