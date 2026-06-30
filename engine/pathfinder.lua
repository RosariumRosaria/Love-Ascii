--NOTE Based off of Redbob
local map = require("map.map")
local entities = require("entities.entities")
local utils = require("utils")
local game_cfg = require("config.game_config")
local stats = require("stats.stats")
local statuses = require("statuses.statuses")

local pathfinder = {}
local max_checks = game_cfg.pathfinding.max_iterations

local function cell_traversal(actor, x, y, z, goal)
	if not map:walkable(x, y, z) then
		return "blocked", nil
	end

	local at_goal = x == goal.x and y == goal.y and z == 1

	local best_kind, best_cost, best_target
	local has_unhandleable = false

	for _, ent in ipairs(entities.get_list_at(x, y, z)) do
		if not utils.get_tag(ent, "walkable") and ent ~= actor then
			local kind, cost
			if
				ent.passage
				and ent.passage.open
				and actor.can_perform
				and actor.can_perform.interactable
				and statuses.can_be_interacted(ent)
			then
				kind, cost = "open", ent.passage.open
			end

			if
				utils.get_tag(ent, "attackable")
				and actor.can_perform
				and actor.can_perform.attackable
				and actor.team ~= ent.team
				and stats.get_current(actor, "damage") > 0
			then
				local bcost = math.ceil(stats.get_current(ent, "health") / stats.get_current(actor, "damage"))
				if not cost or bcost < cost then
					kind, cost = "attack", bcost
				end
			end
			if actor.team and actor.team == ent.team then
				kind, cost = "wait", game_cfg.pathfinding.wait_cost * (actor.mind.impatience + 1)
			end
			if kind then
				if not best_cost or cost < best_cost then
					best_kind, best_cost, best_target = kind, cost, ent
				end
			else
				has_unhandleable = true
			end
		end
	end

	if at_goal then
		return best_kind or "walk", 1, best_target
	end

	if has_unhandleable then
		return "blocked", nil, nil
	end

	if best_kind then
		return best_kind, best_cost, best_target
	end

	return "walk", 1, nil
end

local kind_order = {
	blocked = 1,
	attack = 2,
	open = 3,
	wait = 4,
	walk = 5,
}

function pathfinder.traversal(actor, x, y, z, goal)
	local ret_kind, ret_cost, ret_target = "walk", 1, nil
	local blocked = false
	for _, c in ipairs(utils.footprint_offsets(actor)) do
		local kind, cost, target = cell_traversal(actor, x + c.dx, y + c.dy, z, goal)
		if kind == "blocked" then
			blocked = true
		elseif kind_order[kind] < kind_order[ret_kind] and cost then
			ret_kind, ret_cost, ret_target = kind, cost, target
		end
	end

	-- A blocked footprint cell only stops the body from *moving* onto (x, y); an
	-- attack/open/wait is performed from the current cell, so a blocked sibling
	-- must not mask it. Only fall through to "blocked" when the best outcome was
	-- to walk into the blocked footprint.
	if blocked and ret_kind == "walk" then
		return "blocked", nil
	end

	return ret_kind, ret_cost, ret_target
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
	local arrival = nil
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

		if utils.footprint_reaches(utils.footprint_offsets(actor), current.x, current.y, goal) then
			arrival = current
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

	if not arrival then
		return nil
	end

	return reconstruct_path(came_from, start, arrival)
end

return pathfinder
