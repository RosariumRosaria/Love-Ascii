local map = require("map.map")
local entities = require("entities.entities")
local engine = {}

local function distanceBetween(entity1, entity2)
    if not entity1 then 
        print("entity1 is nil")
    end
    if not entity2 then 
        print("entity2 is nil")
    end
    return math.sqrt((entity1.x - entity2.x)^2 + (entity1.y - entity2.y)^2)
end

local function isTileFree(x, y, z, skipEntities)
    local entityList  = entities:getEntityList()
    if not map:walkable(x, y, z) then return false end
    for _, ent in ipairs(entityList) do
        if not skipEntities[ent] and ent.x == x and ent.y == y then
            return false
        end
    end
    return true
end



function engine:move(entity, dx, dy)
    local tarX = entity.x + dx
    local tarY = entity.y + dy

    if isTileFree(tarX, tarY, entity.z, {[entity] = true}) then
        entity.x = tarX
        entity.y = tarY
        return true
    end

    return false
end

function engine:push(entityPusher, dx, dy)
    local entityPushed = entities:getEntity(entityPusher.x + dx, entityPusher.y + dy)
    if not entityPusher then
        print("Pusher entity is nil")
        return false
    end
    if not entityPushed then
        print("Pushed entity is nil")
        return false
    end
    if distanceBetween(entityPusher, entityPushed) > 1 then
        print("Pusher and pushed entities are too far apart")
        return false
    end 
    if not entityPushed.moveable then
        print("Pushed entity is not moveable")
        return false
    end
 
    

    local pusherTarX = entityPusher.x + dx
    local pusherTarY = entityPusher.y + dy
    local pushedTarX = entityPushed.x + dx
    local pushedTarY = entityPushed.y + dy

    entities:describe(entityPushed)
    if not isTileFree(pusherTarX, pusherTarY, entityPusher.z, {[entityPusher] = true, [entityPushed] = true}) then
        print("Pusher tile not free")
        return false
    end
    if not isTileFree(pushedTarX, pushedTarY, entityPushed.z, {[entityPushed] = true}) then
        print("Pushed tile not free")
        return false
    end

    entityPusher.x = pusherTarX
    entityPusher.y = pusherTarY
    entityPushed.x = pushedTarX
    entityPushed.y = pushedTarY
    print("Pushed entity to " .. pushedTarX .. ", " .. pushedTarY)
    return true
end

function engine:pull(entityPuller, dx, dy)
    local entityPulled = entities:getEntity(entityPuller.x - dx, entityPuller.y - dy)
    if not entityPuller then
        print("Puller entity is nil")
        return false
    end
    if not entityPulled then
        print("Pulled entity is nil")
        return false
    end
    if distanceBetween(entityPuller, entityPulled) > 1 then
        print("Puller and Pulled entities are too far apart")
        return false
    end 
    if not entityPulled.moveable then
        print("Pulled entity is not moveable")
        return false
    end

    local pullerTarX = entityPuller.x + dx
    local pullerTarY = entityPuller.y + dy
    local pulledTarX = entityPulled.x + dx
    local pulledTarY = entityPulled.y + dy

    if not isTileFree(pullerTarX, pullerTarY, entityPuller.z, {[entityPuller] = true}) then
        print("Puller tile not free")
        return false
    end

    if not isTileFree(pulledTarX, pulledTarY, entityPulled.z, {[entityPuller] = true, [entityPulled] = true}) then
        print("Pulled tile not free")
        return false
    end

    entityPuller.x = pullerTarX
    entityPuller.y = pullerTarY
    entityPulled.x = pulledTarX
    entityPulled.y = pulledTarY
    print("Pulled entity to " .. pulledTarX .. ", " .. pulledTarY)
    return true
end


return engine