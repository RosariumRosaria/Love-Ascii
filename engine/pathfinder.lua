--NOTE Based off of Redbob
local map = require("map.map")
local entities = require("entities.entities")
local utils = require("utils")
local game_cfg = require("config.game_config")
local stats = require("stats.stats")

local pathfinder = {}
local max_checks = game_cfg.pathfinding.max_iterations

function pathfinder.traversal(actor, x, y, z, goal)
	if x == goal[1] and y == goal[2] and z == 1 then
		return "walk", 1
	end

	if not map:walkable(x, y, z) then
		return "blocked", nil
	end

	for _, ent in ipairs(entities.get_entities_at(x, y, z)) do
		if not entities.get_tag_entity(ent, "walkable") then
			if
				entities.get_tag_entity(ent, "attackable")
				and actor.allowed_actions
				and actor.allowed_actions.attackable
				and stats.get_current(actor, "damage") > 0
			then
				return "attackable", math.ceil(stats.get_current(ent, "health") / stats.get_current(actor, "damage"))
			end
			return "blocked", nil
		end
	end

	return "walk", 1
end

local function get_neighbors(x, y, goal, actor)
	local candidates = {
		{ x + 1, y },
		{ x - 1, y },
		{ x, y + 1 },
		{ x, y - 1 },
	}

	utils.shuffle(candidates)

	local neighbors = {}
	for _, pos in ipairs(candidates) do
		local kind, cost = pathfinder.traversal(actor, pos[1], pos[2], 1, goal)
		if kind ~= "blocked" then
			table.insert(neighbors, { pos[1], pos[2], kind, cost })
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

function pathfinder.a_star(start, goal, actor)
	local frontier = {}
	utils.priority_queue_put(frontier, start, 0)

	local came_from = {}
	local cost_so_far = {}

	came_from[key(start[1], start[2])] = nil
	cost_so_far[key(start[1], start[2])] = 0

	local i = 0
	while #frontier > 0 and i < max_checks do
		i = i + 1

		local node = utils.priority_queue_get(frontier)
		local current = node[1]

		if current[1] == goal[1] and current[2] == goal[2] then
			break
		end

		for _, ret in ipairs(get_neighbors(current[1], current[2], goal, actor)) do
			local kind, cost = ret[3], ret[4]
			local current_key = key(current[1], current[2])
			local next_key = key(ret[1], ret[2])

			local new_cost = cost_so_far[current_key] + cost
			if cost_so_far[next_key] == nil or new_cost < cost_so_far[next_key] then
				cost_so_far[next_key] = new_cost
				local priority = new_cost + heuristic(goal, ret)
				utils.priority_queue_put(frontier, ret, priority)
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
