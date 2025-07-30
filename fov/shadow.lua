local Shadow = {}
Shadow.__index = Shadow

function Shadow:new(startVal, endVal)
    local obj = setmetatable({}, self)
    obj.startVal = startVal
    obj.endVal = endVal
    return obj
end

function Shadow:Contains(other)
    return self.startVal <= other.startVal and self.endVal >= other.endVal
end

function Shadow.projectTile(row, col)
    local epsilon = 0.0002 
    local topLeft = col / (row + 2) + epsilon
    local bottomRight = (col + 1) / (row + 1) - epsilon
    return Shadow:new(topLeft, bottomRight)
end

return Shadow
