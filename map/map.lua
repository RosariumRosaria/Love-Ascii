local types = require("map.tiletypes")
local render = require("render")
local map = {
    width,
    height,
    depth,
    tileSize,
    tiles = {}
}

function map:inbounds(x, y)
    return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

function map:walkable(x, y)
    if not self:inbounds(x, y) then return false end
    if not self.tiles[y] or not self.tiles[y][x] then return false end
    return self.tiles[y][x].walkable
end

function map:makeBuilding(roomStartX, roomStartY, width, height, depth)
    for y = 1, height do
        for x = 1, width do
            local tileX = roomStartX + x - 1
            local tileY = roomStartY + y - 1
            if self:inbounds(tileX, tileY) then
                if (x == 1 and y == 1) or (x == width and y == height) or (x == 1 and y == height) or (x == width and y == 1) then 
                    self.tiles[tileY][tileX] = types.cWall
                elseif x == 1 or x == width then
                    self.tiles[tileY][tileX] = types.hWall
                elseif y == 1 or y == height then
                    self.tiles[tileY][tileX] = types.vWall
                else
                    self.tiles[tileY][tileX] = types.floor
                end
            end
        end
    end

    local dir = math.random(0, 4)
    local lim = width
    if dir % 2 == 0 then
        lim = height
    end

    local doorStart = math.random(2, lim -1)
    if dir == 1 then  -- left wall
        self.tiles[roomStartY + doorStart - 1][roomStartX][1] = types.floor
    elseif dir == 2 then  -- right wall
        self.tiles[roomStartY + doorStart - 1][roomStartX + width - 1] = types.floor
    elseif dir == 3 then  -- top wall
        self.tiles[roomStartY][roomStartX + doorStart - 1] = types.floor
    elseif dir == 4 then  -- bottom wall
        self.tiles[roomStartY + height - 1][roomStartX + doorStart - 1] = types.floor
    end

    building = {
        startX = roomStartX,
        startY = roomStartY,
        width = width,
        height = height
    }

    return building
end

function map:makeTown(roomCount)
    for y = 1, self.height do
        self.tiles[y] = {} 
        for x = 1, self.width do
            self.tiles[y][x] = types.grass
        end
    end
    for i = 1, roomCount do
        local roomStartX = math.random(0 + 10, self.width - 10)
        local roomStartY = math.random(0 + 10, self.height - 10)
        self:makeBuilding(roomStartX, roomStartY, math.random(5,15), math.random(5,15))
        
    end
end

function map:load(width, height, depth, mapType, tileSize)
    self.width = width or 10
    self.height = height or 10
    self.tileSize = tileSize or 16
    self.depth = depth or 5 
    for y = 1, self.height do
        self.tiles[y] = {}
        for x = 1, self.width do
            self.tiles[y][x] = {}
            self.tiles[y][x][1] = types.grass
        end
    end
    if (mapType == "town") then
        self:makeTown(5) -- Hardcoded for 5, should be changed
    end
end

function map:draw(centerX, centerY, drawDist)

    local endX = math.min(centerX + drawDist, self.width)
    local endY = math.min(centerY + drawDist, self.height)
    local startX = math.max(centerX - drawDist, 1)
    local startY = math.max(centerY - drawDist, 1)


    local screenCenterX = love.graphics.getWidth() / self.tileSize / 2
    local screenCenterY = love.graphics.getHeight() / self.tileSize / 2

    for y = startY, endY do
        for x = startX, endX do
            local drawX = x - centerX + screenCenterX
            local drawY = y - centerY + screenCenterY
            print(self.tiles[y][x][1].char)
            render:draw(self.tiles[y][x], self.tileSize, drawX, drawY)
        end
    end
end

return map