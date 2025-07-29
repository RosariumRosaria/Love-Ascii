local map = require("map.map")
local entities = require("entities.entities")
local visuals = require("visuals.visuals")
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

function engine:attack(entity, dx, dy)
    local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy)
    if not entity then
        print("Attacking entity is nil")
    return false
    end
    if not targetEntity then
        print("Attacked entity is nil")
        return false
    end
    if distanceBetween(entity, targetEntity) > 1 then
        print("Too far apart")
        return false
    end 
    if not targetEntity.attackable then
        print("Target not attackable")
        return false
    end
    visuals:addFromTemplate("attack", entity.x+dx, entity.y+dy, entity.z) 
    entities:damageEntity(targetEntity, entity.damage)
end

function engine:interact(entity, dx, dy)
    local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy)
    if not entity then
        print("Interacting entity is nil")
    return false
    end
    if not targetEntity then
        print("Interacted entity is nil")
        return false
    end
    if distanceBetween(entity, targetEntity) > 1 then
        print("Too far apart")
        return false
    end 
    if not targetEntity.interactable then
        print("Nothing to do here")
        return false
    end
    entities:interactWithEntity(targetEntity)
end

function engine:inspect(entity, dx, dy)
    local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy)
    if not entity then
        print("Inspecting entity is nil")
    return false
    end
    if not targetEntity then
        print("Inspected entity is nil")
        return false
    end
    if distanceBetween(entity, targetEntity) > 1 then
        print("Too far apart")
        return false
    end 

    entities:inspectEntity(targetEntity)
end

function engine:move(entity, dx, dy)
    local tarX = entity.x + dx
    local tarY = entity.y + dy
    if isTileFree(tarX, tarY, entity.z, {[entity] = true}) then       
        visuals:addFromTemplate("trail", entity.x, entity.y, entity.z) 
        entity.x = tarX
        entity.y = tarY
        return true
    end

    return false
end

function engine:push(entity, dx, dy) --TODO Probably some way to integrate pushing and pulling, and to use move
    local targetEntity = entities:getEntity(entity.x + dx, entity.y + dy)
    if not entity then
        print("Pusher entity is nil")
        return false
    end
    if not targetEntity then
        print("Pushed entity is nil")
        return false
    end
    if distanceBetween(entity, targetEntity) > 1 then
        print("Pusher and pushed entities are too far apart")
        return false
    end 
    if not targetEntity.moveable then
        print("Pushed entity is not moveable")
        return false
    end
 
    

    local pusherTarX = entity.x + dx
    local pusherTarY = entity.y + dy
    local pushedTarX = targetEntity.x + dx
    local pushedTarY = targetEntity.y + dy
    if not isTileFree(pusherTarX, pusherTarY, entity.z, {[entity] = true, [targetEntity] = true}) then
        print("Pusher tile not free")
        return false
    end
    if not isTileFree(pushedTarX, pushedTarY, targetEntity.z, {[targetEntity] = true}) then
        print("Pushed tile not free")
        return false
    end
    visuals:addFromTemplate("trail", entity.x, entity.y, entity.z) 
    entity.x = pusherTarX
    entity.y = pusherTarY
    targetEntity.x = pushedTarX
    targetEntity.y = pushedTarY
    print("Pushed entity to " .. pushedTarX .. ", " .. pushedTarY)

    return true
end

function engine:pull(entity, dx, dy)
    local targetEntity = entities:getEntity(entity.x - dx, entity.y - dy)
    if not entity then
        print("Puller entity is nil")
        return false
    end
    if not targetEntity then
        print("Pulled entity is nil")
        return false
    end
    if distanceBetween(entity, targetEntity) > 1 then
        print("Puller and Pulled entities are too far apart")
        return false
    end 
    if not targetEntity.moveable then
        print("Pulled entity is not moveable")
        return false
    end

    local pullerTarX = entity.x + dx
    local pullerTarY = entity.y + dy
    local pulledTarX = targetEntity.x + dx
    local pulledTarY = targetEntity.y + dy

    if not isTileFree(pullerTarX, pullerTarY, entity.z, {[entity] = true}) then
        print("Puller tile not free")
        return false
    end

    if not isTileFree(pulledTarX, pulledTarY, targetEntity.z, {[entity] = true, [targetEntity] = true}) then
        print("Pulled tile not free")
        return false
    end
    visuals:addFromTemplate("trail", entity.x, entity.y, entity.z) 
    entity.x = pullerTarX
    entity.y = pullerTarY
    targetEntity.x = pulledTarX
    targetEntity.y = pulledTarY
    print("Pulled entity to " .. pulledTarX .. ", " .. pulledTarY)

    return true
end




return engine