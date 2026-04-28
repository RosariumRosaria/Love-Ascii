local shadow_line = {}

shadow_line.__index = shadow_line

function shadow_line:new()
	local obj = setmetatable({}, self)
	obj.shadows = {}
	return obj
end

function shadow_line:is_in_shadow(projection)
	for _, shadow in ipairs(self.shadows) do
		if shadow:contains(projection) then
			return true
		end
	end
	return false
end

function shadow_line:is_full_shadow()
	return #self.shadows == 1 and self.shadows[1].start_val == 0 and self.shadows[1].end_val == 1
end

function shadow_line:add_shadow(new_shadow) -- Maybe review? Seems to work
	local i = 1
	while i <= #self.shadows and self.shadows[i].end_val < new_shadow.start_val do
		i = i + 1
	end

	local j = i
	while j <= #self.shadows and self.shadows[j].start_val <= new_shadow.end_val do
		new_shadow.start_val = math.min(new_shadow.start_val, self.shadows[j].start_val)
		new_shadow.end_val = math.max(new_shadow.end_val, self.shadows[j].end_val)
		j = j + 1
	end

	for _ = i, j - 1 do
		table.remove(self.shadows, i)
	end

	table.insert(self.shadows, i, new_shadow)
end

return shadow_line
