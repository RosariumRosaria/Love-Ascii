local utils = {}

function utils.clamp(val, min, max)
	return math.max(min, math.min(max, val))
end

function utils.in_bounds(x, y, width, height)
	return x >= 1 and x <= width and y >= 1 and y <= height
end

function utils.deep_copy(tbl)
	local copy = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			copy[k] = utils.deep_copy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function utils.contains(tbl, val)
	for _, v in ipairs(tbl) do
		if v == val then
			return true
		end
	end
	return false
end

function utils.shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

return utils
