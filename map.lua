local types = require("tiletypes")

map = {
    width,
    height,
    tilesize,
    tiles = {}
}


function map:makeDungeon(roomCount, roomSize, mapSize)
    for y = 1, self.height do
        self.tiles[y] = {} 
        for x = 1, self.width do
            self.tiles[y][x] = types.grass
        end
    end
end

function map:load(width, height, tilesize, dungeonType)
    self.width = width or 10
    self.height = height or 10
    self.tilesize = tilesize or 32
    if (dungeonType == "dungeon") then
        self:makeDungeon(5, 10, {width = self.width, height = self.height})
    else
        -- Other map types can be handled here
        for y = 1, self.height do
            self.tiles[y] = {}
            for x = 1, self.width do
                self.tiles[y][x] = types.grass
            end
        end
    end
end

function map:draw()
    for y = 1, self.height do
        for x = 1, self.width do
            local tile = self.tiles[y][x]
            love.graphics.print(tile.char, (x-1)*self.tilesize+(tilesize/2), (y-1)*self.tilesize+(tilesize/2))
        end
    end
end