--NOTE Based off of Redbob
local map = require("map.map")
local entities = require("entities.entities")
local utils = require("utils")
local game_cfg = require("config.game_config")
local stats = require("stats.stats")

local pathfinder = {}
local max_checks = game_cfg.pathfinding.max_iterations

function pathfinder.traversal(actor, x, y, z, goal)
	if not map:walkable(x, y, z) then
		return "blocked", nil
	end

	local at_goal = x == goal.x and y == goal.y and z == 1

	local best_kind, best_cost
	local has_unhandleable = false

	for _, ent in ipairs(entities.get_list_at(x, y, z)) do
		if not entities.get_tag(ent, "walkable") then
			local kind, cost
			if ent.passage and ent.passage.open and actor.allowed_actions and actor.allowed_actions.interactable then
				kind, cost = "open", ent.passage.open
			end
			if
				entities.get_tag(ent, "attackable")
				and actor.allowed_actions
				and actor.allowed_actions.attackable
				and stats.get_current(actor, "damage") > 0
			then
				local bcost = math.ceil(stats.get_current(ent, "health") / stats.get_current(actor, "damage"))
				if not cost or bcost < cost then
					kind, cost = "attackable", bcost
				end
			end

			if kind then
				if not best_cost or cost < best_cost then
					best_kind, best_cost = kind, cost
				end
			else
				has_unhandleable = true
			end
		end
	end

	if at_goal then
		return best_kind or "walk", 1
	end

	if has_unhandleable then
		return "blocked", nil
	end

	if best_kind then
		return best_kind, best_cost
	end

	return "walk", 1
end

local function get_neighbors(x, y, goal, actor)
	local candidates = {
		{ x = x + 1, y = y },
		{ x = x - 1, y = y },
		{ x = x, y = y + 1 },
		{ x = x, y = y - 1 },
	}

	utils.shuffle(candidates)

	local neighbors = {}
	for _, pos in ipairs(candidates) do
		local kind, cost = pathfinder.traversal(actor, pos.x, pos.y, 1, goal)
		if kind ~= "blocked" then
			table.insert(neighbors, { x = pos.x, y = pos.y, kind = kind, cost = cost })
		end
	end
	return neighbors
end

local function heuristic(a, b)
	return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

local function key(x, y)
	return x .. "," .. y
end

local function reconstruct_path(came_from, start, goal)
	local current = goal
	local path = { goal }

	while current.x ~= start.x or current.y ~= start.y do
		current = came_from[key(current.x, current.y)]
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

	came_from[key(start.x, start.y)] = nil
	cost_so_far[key(start.x, start.y)] = 0

	local i = 0
	while #frontier > 0 and i < max_checks do
		i = i + 1

		local node = utils.priority_queue_get(frontier)
		local current = node[1]

		if current.x == goal.x and current.y == goal.y then
			break
		end

		for _, ret in ipairs(get_neighbors(current.x, current.y, goal, actor)) do
			local kind, cost = ret.kind, ret.cost
			local current_key = key(current.x, current.y)
			local next_key = key(ret.x, ret.y)

			local new_cost = cost_so_far[current_key] + cost
			if cost_so_far[next_key] == nil or new_cost < cost_so_far[next_key] then
				cost_so_far[next_key] = new_cost
				local priority = new_cost + heuristic(goal, ret)
				utils.priority_queue_put(frontier, ret, priority)
				came_from[next_key] = current
			end
		end
	end

	local goal_key = key(goal.x, goal.y)
	if not came_from[goal_key] then
		return nil
	end

	return reconstruct_path(came_from, start, goal)
end

return pathfinder
