local ui_handler = require("visuals.ui")

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

function utils.priority_queue_put(queue, node, priority)
	for i = 1, #queue do
		if queue[i][2] > priority then
			table.insert(queue, i, { node, priority })
			return
		end
	end
	table.insert(queue, { node, priority })
end

function utils.priority_queue_get(queue)
	local ret = queue[1]
	table.remove(queue, 1)
	return ret
end

function utils.in_radius(dx, dy, r)
	return dx * dx + dy * dy <= r * r
end

function utils.deep_print(tbl, indent, visited)
	indent = indent or 0
	visited = visited or {}

	if visited[tbl] then
		print(string.rep("  ", indent) .. "*recursive reference*")
		return
	end
	visited[tbl] = true

	for k, v in pairs(tbl) do
		local key_str = tostring(k)
		if type(v) == "table" then
			ui_handler:add_text_to_ui_by_name("terminal", (string.rep("  ", indent) .. key_str .. " = {"))
			print(string.rep("  ", indent) .. key_str .. " = {")
			utils.deep_print(v, indent + 1, visited)
			ui_handler:add_text_to_ui_by_name("terminal", (string.rep("  ", indent) .. "}"))
			print((string.rep("  ", indent) .. "}"))
		else
			ui_handler:add_text_to_ui_by_name("terminal", (string.rep("  ", indent) .. key_str .. " = " .. tostring(v)))
			print((string.rep("  ", indent) .. key_str .. " = " .. tostring(v)))
		end
	end
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
