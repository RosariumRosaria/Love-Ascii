local visualTypes = require("visuals/visualTypes") 

local visuals = {
    visualList = {},
    visualTypeDict = {}
}

function visuals:getVisual(x, y, z)
    for _, visual in ipairs(self.visualList) do
        if visual.x == x and visual.y == y and visual.z == z then
            return visual
        end
    end
end

function visuals:getVisualList()
    return self.visualList
end

function visuals:addVisual(visual)
    table.insert(self.visualList, visual)
end

function visuals:addFromTemplate(name, x, y, z)
    local template = visualTypes[name]
    if not template then
        error("Visual type '" .. tostring(name) .. "' does not exist")
    end



    local newVisual = {}

    for k, v in pairs(template) do
        if type(v) == "table" then
            newVisual[k] = { unpack(v) }  -- shallow copy of table
        else
            newVisual[k] = v
        end
    end

    newVisual.x = x or 1
    newVisual.y = y or 1
    newVisual.z = z or 1

    self:addVisual(newVisual)
    return newVisual
end

function visuals:describe(visual) --TODO, make a generic helper file, maybe this, bounds? Possibly Create from template
    if not visual then
        print("Visual is nil!")
        return false;
    end
    for k, v in pairs(visual) do
        print("key: " .. tostring(k) .. "value: " .. tostring(v))
    end
end

function visuals:update(dt)
    for i = #self.visualList, 1, -1 do
        local visual = self.visualList[i]
        visual.lifespan = visual.lifespan - dt
        if visual.lifespan <= 0 then
            if #visual.colors > visual.i then
                visual.i = visual.i + 1
                visual.lifespan = visual.initialSpan
            else
                table.remove(self.visualList, i) -- remove the visual completely
            end
        end
    end
end


return visuals