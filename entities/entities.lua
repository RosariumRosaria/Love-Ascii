local entityTypes = require("entities/entityTypes") 

local entities = {
    entityList = {}
}

function entities:getTransparency(x,y)
    entity = entities:getEntity(x,y)

    if not entity then
        return true
    end

    return entity.transparent
end

 function entities:getEntity(x, y)
    for _, entity in ipairs(self.entityList) do
        if entity.x == x and entity.y == y then
            return entity
        end
    end
end

function entities:getEntityList()
    return self.entityList
end

function entities:addEntity(entity)
    table.insert(self.entityList, entity)
end

function entities:addFromTemplate(name, x, y, z)
    local template = entityTypes[name]
    if not template then
        error("Entity type '" .. tostring(name) .. "' does not exist")
    end
    local newEntity = {}

    for k, v in pairs(template) do
        newEntity[k] = v
    end

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