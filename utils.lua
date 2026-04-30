local utils = {}

function utils.clamp(val, min, max)
	return math.max(min, math.min(max, val))
end

function utils.in_bounds(x, y, max_x, max_y)
	return x >= 1 and x <= max_x and y >= 1 and y <= max_y
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

function utils.in_radius(dx, dy, r)
	return dx * dx + dy * dy <= r * r
end

function utils.overlapping_rectangles(r1, r2)
	return not (
		r1.x + r1.width <= r2.x
		or r2.x + r2.width <= r1.x
		or r1.y + r1.height <= r2.y
		or r2.y + r2.height <= r1.y
	)
end

return utils
