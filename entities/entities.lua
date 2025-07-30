local entityTypes = require("entities/entity_types") 

local entities = {
    entityList = {},
    tilelikeList = {}
}

function entities:getTransparency(x,y,z)
    entity = entities:getEntity(x,y,z)
    if not entity then
        return true
    end

    return entity.transparent
end

function entities:damageEntity(entity, damage)
    if entity then
        entity.health = entity.health - damage
        print("You hit " .. entity.name .. " " .. entity.health .. " remaining!")
        if entity.health <= 0 then
            entities:removeEntity(entity)
        end
    end
end

function entities:interactWithEntity(entity) --TODO
    local interaction = entity.interaction
    if not interaction then return end
    print("Before:", entity.char, entity.walkable)
    for k, v in pairs(interaction) do
        local vv  = entity[k]
        entity[k] = v
        interaction[k] = vv
    end
    print("After:", entity.char, entity.walkable)
end

function entities:inspectEntity(entity)
    if entity.description then
        print(entity.description)
    end 
end


 function entities:getEntity(x, y, z)
    for _, entity in ipairs(self.entityList) do
        if entity.x == x and entity.y == y and entity.z == z then
            return entity
        end
    end
end

function entities:removeEntity(target)
    for i, entity in ipairs(self.entityList) do
        if entity == target then
            table.remove(self.entityList, i)
            return true
        end
    end

    if entity.tilelike then
        for i, entity in ipairs(self.tilelikeList) do
            if entity == target then
                table.remove(self.tilelikeList, i)
                return true
            end
        end
    end

    return false
end

function entities:getEntityList()
    return self.entityList
end

function entities:addEntity(entity)
    table.insert(self.entityList, entity)
    if entity.tilelike then
        table.insert(self.tilelikeList, entity)
    end
end



local function deepCopy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function entities:addFromTemplate(name, x, y, z)
    local template = entityTypes[name]
    if not template then
        error("Entity type '" .. tostring(name) .. "' does not exist")
    end
    local newEntity = deepCopy(template)

    newEntity.x = x or 1
    newEntity.y = y or 1
    newEntity.z = z or 1

    self:addEntity(newEntity)
    return newEntity
end

function entities:describe(entity)
    if not entity then
        print("Entity is nil!")
        return false;
    end
    for k, v in pairs(entity) do
        print("key: " .. tostring(k) .. "value: " .. tostring(v))
    end
end

return entities