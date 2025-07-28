local ShadowLine = {}

ShadowLine.__index = ShadowLine


function ShadowLine:new()
    local obj = setmetatable({}, self)
    obj.shadows = {}
    return obj
end

function ShadowLine:isInShadow(projection)
    assert(self.shadows, "self.shadows is nil in isInShadow")
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

function ShadowLine:AddShadow(newShadow)
    local i = 1
    for _, other in ipairs(self.shadows) do
      if (other.startVal >= newShadow.startVal) then
        break
      end
      i  = i + 1
    end

    local overlapPrev = nil;
    if (i > 1 and self.shadows[i-1].endVal >= newShadow.startVal) then
        overlapPrev = self.shadows[i-1]
    end

    local overlapNext = nil;
    if (i < #self.shadows and self.shadows[i].startVal <= newShadow.endVal) then 
        overlapNext = self.shadows[i]
    end

    if overlapNext then
        if overlapPrev then
            -- overlapping both sides
            overlapPrev.endVal = overlapNext.endVal
            table.remove(self.shadows, i)
        else
            -- overlapping next
            overlapNext.startVal = newShadow.startVal
        end
    elseif overlapPrev then
        -- overlapping last
        overlapPrev.endVal = newShadow.endVal
    else
        -- no overlap, just add it
        table.insert(self.shadows, i, newShadow)
    end
end

return ShadowLine