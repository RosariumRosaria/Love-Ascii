local types = require("map.tile_types")
local renderer = require("visuals.renderer")
local fov_handler = require("fov.fov_handler")
local entities = require("entities.entities")

local map = {
    width = nil,
    height = nil,
    depth = nil,
    tileSize = nil,
    tiles = {},
    visible = {},
    explored = {}
}


function map:inbounds(x, y) -- Can maybe moved to separate file
    return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

function map:walkable(x, y, z)
    if not self:inbounds(x, y) then return false end
    if not self.tiles[y] or not self.tiles[y][x][z] then return false end
    return self.tiles[y][x][z].walkable
end

function map:isVisible(x, y)
    if not self:inbounds(x, y) then return false end
    return self.visible[y][x]
end

function map:isExplored(x, y)
    if not self:inbounds(x, y) then return false end
    return self.explored[y][x]
end

function map:overlapRect(r1, r2)
    return not (
        r1.x + r1.width <= r2.x or
        r2.x + r2.width <= r1.x or
        r1.y + r1.height <= r2.y or
        r2.y + r2.height <= r1.y
    )
end

function map:makeBuilding(roomStartX, roomStartY, width, height, depth) -- Todo, can probably move this and make town to a different file
    for y = 1, height do
        for x = 1, width do
            local tileX = roomStartX + x - 1
            local tileY = roomStartY + y - 1
            if self:inbounds(tileX, tileY) then
                if (x == 1 and y == 1) or (x == width and y == height) or (x == 1 and y == height) or (x == width and y == 1) then
                    for z = 1, depth do
                        self.tiles[tileY][tileX][z] = types.cWall
                    end
                elseif x == 1 or x == width then
                    for z = 1, depth do
                        self.tiles[tileY][tileX][z] = types.hWall
                    end
                elseif y == 1 or y == height then
                    for z = 1, depth do
                        self.tiles[tileY][tileX][z] = types.vWall
                    end
                else
                    self.tiles[tileY][tileX][1] = types.floor
                end
            end
        end
    end

    local dir = math.random(1, 4)
    local lim = width
    if dir % 2 == 0 then
        lim = height
    end

    local doorStart = math.random(2, lim - 2)
    local leftY = doorStart + roomStartY - 2
    local leftX  = roomStartX
    local rightY = doorStart + roomStartY - 1
    local rightX  = roomStartX + width - 1
    local upY = roomStartY
    local upX = roomStartX + doorStart - 1
    local downY = roomStartY + height - 1
    local downX = roomStartX + doorStart - 1
    if dir == 1 then
        self.tiles[leftY][leftX][1] = types.floor
        self.tiles[leftY][leftX][2] = types.air
        entities:addFromTemplate("door", leftX, leftY, 1)
    else
        self.tiles[leftY][leftX][2] = types.air
        entities:addFromTemplate("window", leftX, leftY, 1)
    end
    if dir == 2 then
        self.tiles[rightY][rightX][1] = types.floor
        self.tiles[rightY][rightX][2] = types.air
        entities:addFromTemplate("door", rightX, rightY, 1)
    else
        self.tiles[rightY][rightX][2] = types.air
        entities:addFromTemplate("window", rightX, rightY, 1)
    end
    if dir == 3 then
        self.tiles[upY][upX][1] = types.floor
        self.tiles[upY][upX][2] = types.air
        entities:addFromTemplate("door", upX, upY, 1)
    else
        self.tiles[upY][upX][2] = types.air
        entities:addFromTemplate("window", upX, upY, 1)
    end
    if dir == 4 then
        self.tiles[downY][downX][1] = types.floor
        self.tiles[downY][downX][2] = types.air
        entities:addFromTemplate("door", downX, downY, 1)
    else
        self.tiles[downY][downX][2] = types.air
        entities:addFromTemplate("window", downX, downY, 1)
    end
 --TODO, this might cause problems when you add pathfinding, as entities might require map


    local building = {
        x = roomStartX,
        y = roomStartY,
        width = width,
        height = height
    }

    return building
end

function map:makeTown(roomCount)
    for y = 1, self.height do
        for x = 1, self.width do
            self.tiles[y][x][1] = types.grass
            if (math.random(1, 15) == 15) then
                self.tiles[y][x][1] = types.shrub
            end
        end
    end


    local buildings = {}

    for i = 1, roomCount do
        local potentialBuilding
        local overLaps = true

        while overLaps do
            overLaps = false

            local x = math.random(10, self.width - 20) --TODO make fix magic numbers
            local y = math.random(10, self.height - 20)
            local w = math.random(5, 15)
            local h = math.random(5, 15)
            potentialBuilding = { x = x, y = y, width = w, height = h }

            for _, other in ipairs(buildings) do
                if self:overlapRect(potentialBuilding, other) then
                    overLaps = true
                    break
                end
            end
        end

        table.insert(buildings, potentialBuilding)
        self:makeBuilding(potentialBuilding.x, potentialBuilding.y, potentialBuilding.width, potentialBuilding.height,
            math.random(2, self.depth))
    end
end

function map:load(width, height, depth, mapType, tileSize)
   -- math.randomseed(os.time())
    self.width = width or 10
    self.height = height or 10
    self.tileSize = tileSize or 16
    self.depth = depth or 5
    for y = 1, self.height do
        self.tiles[y] = {}
        self.visible[y] = {}
        self.explored[y] = {}
        for x = 1, self.width do
            self.tiles[y][x] = {}
            self.visible[y][x] = false
            self.explored[y][x] = false
            self.tiles[y][x][1] = types.grass
        end
    end
    if (mapType == "town") then
        self:makeTown(5) -- TODO Hardcoded for 5, should be changed
    end
end

function map:updateVisibility(centerX, centerY, radius)


    for y = 1, (self.height) do -- TODO SO INEFFICIENT, but works for now
        for x = 1, (self.width) do
            self.visible[y][x] = false
        end
    end

    fov_handler:refreshVisibility(centerX, centerY, radius, self.width, self.height, self.tiles, self.visible)

    for y = 1, self.height do -- TODO SO INEFFICIENT, but works for now
        for x = 1, self.width do
            if self.visible[y][x] then
                self.explored[y][x] = true
            end
        end
    end
end

function map:draw(centerX, centerY, drawDist)
    local endX = math.min(centerX + drawDist, self.width)
    local endY = math.min(centerY + drawDist, self.height)
    local startX = math.max(centerX - drawDist, 1)
    local startY = math.max(centerY - drawDist, 1)
    for y = startY, endY do
        for x = startX, endX do
            if self.visible[y][x] then
                renderer:draw(self.tiles[y][x], self.tileSize, x, y, centerX, centerY, true)
            elseif self.explored[y][x] then
                renderer:draw(self.tiles[y][x],  self.tileSize, x, y, centerX, centerY, false)
            end
        end
    end
end

return map
