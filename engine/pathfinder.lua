--NOTE Based off of Redbob
local map = require("map.map")
local entities = require("entities.entities")
local utils = require("utils")
local game_cfg = require("config.game_config")

local pathfinder = {}
local max_checks = game_cfg.pathfinding.max_iterations

local function is_tile_free(x, y, z, entity_list, goal)
	if x == goal[1] and y == goal[2] and z == 1 then
		return true
	end

	if not map:walkable(x, y, z) then
		return false
	end

	for _, ent in ipairs(entity_list) do
		if not entities:get_tag_entity(ent, "walkable") and ent.x == x and ent.y == y and ent.z == z then
			return false
		end
	end

	return true
end

local function put(queue, node, priority)
	for i = 1, #queue do
		if queue[i][2] > priority then
			table.insert(queue, i, { node, priority })
			return
		end
	end
	table.insert(queue, { node, priority })
end

local function get(queue)
	local ret = queue[1]
	table.remove(queue, 1)
	return ret
end

local function get_neighbors(x, y, entity_list, goal)
	local candidates = {
		{ x + 1, y },
		{ x - 1, y },
		{ x, y + 1 },
		{ x, y - 1 },
	}

	utils.shuffle(candidates)

	local neighbors = {}
	for _, pos in ipairs(candidates) do
		if is_tile_free(pos[1], pos[2], 1, entity_list, goal) then
			table.insert(neighbors, pos)
		end
	end
	return neighbors
end

local function heuristic(a, b)
	return math.abs(a[1] - b[1]) + math.abs(a[2] - b[2])
end

local function key(x, y)
	return x .. "," .. y
end

local function reconstruct_path(came_from, start, goal)
	local current = goal
	local path = { goal }

	while current[1] ~= start[1] or current[2] ~= start[2] do
		current = came_from[key(current[1], current[2])]
		if not current then
			return {}
		end
		table.insert(path, 1, current)
	end

	return path
end

function pathfinder.a_star(start, goal)
	local entity_list = entities:get_entity_list()

	local frontier = {}
	put(frontier, start, 0)

	local came_from = {}
	local cost_so_far = {}

	came_from[key(start[1], start[2])] = nil
	cost_so_far[key(start[1], start[2])] = 0

	local i = 0
	while #frontier > 0 and i < max_checks do
		i = i + 1

		local node = get(frontier)
		local current = node[1]

		if current[1] == goal[1] and current[2] == goal[2] then
			break
		end

		for _, next in ipairs(get_neighbors(current[1], current[2], entity_list, goal)) do
			local current_key = key(current[1], current[2])
			local next_key = key(next[1], next[2])
			local new_cost = cost_so_far[current_key] + 1

			if cost_so_far[next_key] == nil or new_cost < cost_so_far[next_key] then
				cost_so_far[next_key] = new_cost
				local priority = new_cost + heuristic(goal, next)
				put(frontier, next, priority)
				came_from[next_key] = current
			end
		end
	end

	local goal_key = key(goal[1], goal[2])
	if not came_from[goal_key] then
		return nil
	end

	return reconstruct_path(came_from, start, goal)
end

return pathfinder
