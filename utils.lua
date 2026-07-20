local utils = {}

function utils.clamp(val, min, max)
	return math.max(min, math.min(max, val))
end

function utils.lerp(a, b, f)
	return a + (b - a) * f
end

function utils.in_bounds(x, y, max_x, max_y)
	return x >= 1 and x <= max_x and y >= 1 and y <= max_y
end

function utils.get_neighbors(x, y, max_x, max_y)
	local neighbors = {}
	local offsets = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
	for _, o in ipairs(offsets) do
		local nx, ny = x + o[1], y + o[2]
		if utils.in_bounds(nx, ny, max_x, max_y) then
			table.insert(neighbors, { x = nx, y = ny })
		end
	end
	return neighbors
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
		local j = love.math.random(1, i)
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

function utils.distance_between(a, b)
	return utils.distance_between_coords(a.x, a.y, b.x, b.y)
end

function utils.footprint_reaches(offsets, ax, ay, goal, stop_dist)
	for _, c in ipairs(offsets) do
		local cx, cy = ax + c.dx, ay + c.dy
		if math.abs(cx - goal.x) + math.abs(cy - goal.y) <= (stop_dist or 0) then
			return true
		end
	end
	return false
end

local SINGLE_FOOTPRINT = { { dx = 0, dy = 0 } }
function utils.footprint_offsets(entity)
	return entity.footprint or SINGLE_FOOTPRINT
end

function utils.footprint_cells(entity)
	local ret = {}
	for _, c in ipairs(utils.footprint_offsets(entity)) do
		ret[#ret + 1] = { x = entity.x + c.dx, y = entity.y + c.dy }
	end
	return ret
end

function utils.render_x(entity)
	local a = entity.anim
	return (a and a.render_x) or entity.x
end

function utils.render_y(entity)
	local a = entity.anim
	return (a and a.render_y) or entity.y
end

function utils.render_z(entity)
	local a = entity.anim
	return (a and a.render_z) or entity.z
end

function utils.get_center_of_footprint(entity)
	if not entity.footprint then
		return 0, 0
	end
	local min_x, min_y, max_x, max_y

	for _, c in ipairs(entity.footprint) do
		if not min_x or c.dx < min_x then
			min_x = c.dx
		end
		if not min_y or c.dy < min_y then
			min_y = c.dy
		end
		if not max_x or c.dx > max_x then
			max_x = c.dx
		end
		if not max_y or c.dy > max_y then
			max_y = c.dy
		end
	end

	return (min_x + max_x) / 2, (min_y + max_y) / 2
end

function utils.distance_between_coords(x1, y1, x2, y2)
	return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end
function utils.deep_print(tbl, indent, visited)
	indent = indent or 0
	visited = visited or {}

	if visited[tbl] then
		print(string.rep("  ", indent) .. "*recursive reference*")
		return
	end
	visited[tbl] = true
	local panels = require("visuals.panels")
	for k, v in pairs(tbl) do
		local key_str = tostring(k)
		if type(v) == "table" then
			panels:add_text_to_panel_by_name("terminal", (string.rep("  ", indent) .. key_str .. " = {"))
			print(string.rep("  ", indent) .. key_str .. " = {")
			utils.deep_print(v, indent + 1, visited)
			panels:add_text_to_panel_by_name("terminal", (string.rep("  ", indent) .. "}"))
			print((string.rep("  ", indent) .. "}"))
		else
			panels:add_text_to_panel_by_name("terminal", (string.rep("  ", indent) .. key_str .. " = " .. tostring(v)))
			print((string.rep("  ", indent) .. key_str .. " = " .. tostring(v)))
		end
	end
end

function utils.sign(n)
	return n > 0 and 1 or (n < 0 and -1 or 0)
end

function utils.create_instance_from_template(templates, name, overrides)
	local t = templates[name] or error("'" .. tostring(name) .. "' does not exist")
	local instance = utils.deep_copy(t)
	if overrides then
		for k, v in pairs(overrides) do
			instance[k] = v
		end
	end
	instance.key = instance.key or name
	return instance
end

function utils.overlapping_rectangles(r1, r2)
	return not (
		r1.x + r1.width <= r2.x
		or r2.x + r2.width <= r1.x
		or r1.y + r1.height <= r2.y
		or r2.y + r2.height <= r1.y
	)
end

function utils.chance(percent)
	return love.math.random() < percent / 100
end

function utils.randomize_sign()
	if utils.chance(50) then
		return -1
	end
	return 1
end

function utils.randomize_flicker(light)
	if light and light.flicker then
		light.flicker.phase = love.math.random() * 2 * math.pi
	end
end

function utils.remove_from_list(list, target)
	for i, item in ipairs(list) do
		if item == target then
			table.remove(list, i)
			return true
		end
	end
	return false
end

function utils.pick(list)
	return list[love.math.random(#list)]
end

function utils.pick_weighted(entries)
	local sum_weights = 0
	for _, entry in ipairs(entries) do
		sum_weights = sum_weights + (entry.weight or 0)
	end

	if sum_weights <= 0 then
		return nil
	end

	local r = love.math.random() * sum_weights
	for _, entry in ipairs(entries) do
		r = r - (entry.weight or 0)
		if r < 0 then
			return entry
		end
	end

	return entries[#entries]
end

function utils.get_tag(taggable, tag)
	return taggable.tags and taggable.tags[tag]
end

function utils.has_tag(taggables, tag)
	if not taggables then
		return false
	end
	for _, taggable in ipairs(taggables) do
		if utils.get_tag(taggable, tag) then
			return true
		end
	end
	return false
end

function utils.with_tag(taggables, tag)
	local ret = {}
	if not taggables then
		return ret
	end
	for _, taggable in ipairs(taggables) do
		if utils.get_tag(taggable, tag) then
			table.insert(ret, taggable)
		end
	end
	return ret
end

function utils.find_with_tag(taggables, tag)
	if not taggables then
		return nil
	end
	for _, taggable in ipairs(taggables) do
		if utils.get_tag(taggable, tag) then
			return taggable
		end
	end
	return nil
end

return utils
