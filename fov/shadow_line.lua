local ShadowLine = {}

ShadowLine.__index = ShadowLine


function ShadowLine:new()
    local obj = setmetatable({}, self)
    obj.shadows = {}
    return obj
end

function ShadowLine:isInShadow(projection)
    for _, shadow in ipairs(self.shadows) do
        if shadow:Contains(projection) then
            return true
        end
    end
    return false
end

function ShadowLine:isFullShadow()
    return #self.shadows == 1 and self.shadows[1].startVal == 0 and self.shadows[1].endVal == 1
end

function ShadowLine:AddShadow(newShadow) -- Maybe review? Seems to work

    local i = 1
    while i <= #self.shadows and self.shadows[i].endVal < newShadow.startVal do
        i = i + 1
    end

    local j = i
    while j <= #self.shadows and self.shadows[j].startVal <= newShadow.endVal do
        newShadow.startVal = math.min(newShadow.startVal, self.shadows[j].startVal)
        newShadow.endVal = math.max(newShadow.endVal, self.shadows[j].endVal)
        j = j + 1
    end

    for _ = i, j - 1 do
        table.remove(self.shadows, i)
    end

    table.insert(self.shadows, i, newShadow)
end


return ShadowLine