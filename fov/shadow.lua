local Shadow = {}
Shadow.__index = Shadow

function Shadow:new(start_val, end_val)
	local obj = setmetatable({}, self)
	obj.start_val = start_val
	obj.end_val = end_val
	return obj
end

function Shadow:contains(other)
	return self.start_val <= other.start_val and self.end_val >= other.end_val
end

function Shadow.project_tile(row, col)
	local epsilon = 0.00002
	local top_left = col / (row + 2) + epsilon
	local bottom_right = (col + 1) / (row + 1) - epsilon
	return Shadow:new(top_left, bottom_right)
end

return Shadow
