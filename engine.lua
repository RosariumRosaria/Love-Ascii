local map = require("map.map")
local engine = {}

function engine:move(entity, dx, dy, target, entities)
    local tarX = entity.x + dx
    local tarY = entity.y + dy
    if (map:walkable(tarX, tarY, entity.z)) then
        for _, other in ipairs(entities) do
            if other ~= entity and other.x == tarX and other.y == tarY then
                return false
            end
        end
        entity.x = tarX
        entity.y = tarY
        return true
    end
    return false
end

return engine