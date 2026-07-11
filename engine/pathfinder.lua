--NOTE Based off of Redbob
local map = require("map.map")
local entities = require("entities.entities")
local utils = require("utils")
local game_cfg = require("config.game_config")
local ai_cfg = require("config.ai_config")
local stats = require("stats.stats")
local statuses = require("statuses.statuses")
local actions = require("engine.actions")

local pathfinder = {}
local max_checks = game_cfg.pathfinding.max_iterations
local action_cost = game_cfg.action_cost
local stride = ai_cfg.avoid.stride

local passage_terminal = {
	walkable = { kind = "walk", cost = action_cost.move },

	vaultable = { kind = "vault", cost = math.max(action_cost.vault - action_cost.move, 1) },
}

local function hits_cost(damage, hp)
	return math.ceil(hp / damage) * action_cost.attack
end

local function can_attack(actor, ent, damage)
	return damage > 0 and utils.get_tag(ent, "attackable") and actor.team ~= ent.team
end

local function destroy_cost(damage, ent)
	return hits_cost(damage, statuses.absorb_pool(ent) + stats.get_current(ent, "health"))
end

local function passage_traversal(actor, ent, landing, damage)
	local terminal = ent.passage and passage_terminal[ent.passage.kind]
	if not terminal or not actor.can_perform then
		return nil
	end
	if ent.passage.kind == "vaultable" and landing ~= "free" then
		if landing == "occupied" and not ent.footprint then
			return "wait", game_cfg.pathfinding.wait_cost
		end
		return nil
	end

	local remaining = terminal.cost
	local needs_open = not utils.get_tag(ent, ent.passage.kind)
	if needs_open then
		if not actor.can_perform.interactable then
			return nil
		end
		remaining = remaining + action_cost.interact
	end

	local pool = statuses.absorb_pool(ent)
	if pool > 0 then
		if not can_attack(actor, ent, damage) then
			return nil
		end
		return "attack", hits_cost(damage, pool) + remaining
	end

	if needs_open then
		if not statuses.can_be_interacted(ent) then
			return nil
		end
		return "open", remaining
	end

	return terminal.kind, remaining
end

local function cell_traversal(actor, x, y, z, goal, landing, damage)
	if not map:walkable(x, y, z) then
		for _, ent in ipairs(entities.get_list_at(x, y, z)) do
			if ent.passage and ent.passage.kind == "vaultable" then
				local kind, cost = passage_traversal(actor, ent, landing, damage)
				if kind then
					if kind == "wait" then
						cost = cost + (actor.mind.avoid[y + (x * stride)] or 0)
					end
					return kind, cost, ent
				end
			end
		end
		return "blocked"
	end

	local at_goal = x == goal.x and y == goal.y and z == 1

	local best_kind, best_cost, best_target
	local has_unhandleable = false

	for _, ent in ipairs(entities.get_list_at(x, y, z)) do
		if not utils.get_tag(ent, "walkable") and ent ~= actor then
			local kind, cost = passage_traversal(actor, ent, landing, damage)

			if can_attack(actor, ent, damage) then
				local bcost = destroy_cost(damage, ent)
				if not cost or bcost < cost then
					kind, cost = "attack", bcost
				end
			end
			if actor.team and actor.team == ent.team then
				kind, cost = "wait", game_cfg.pathfinding.wait_cost
			end

			if kind then
				if kind == "wait" then
					cost = cost + (actor.mind.avoid[y + (x * stride)] or 0)
				end
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
	vault = 3,
	open = 4,
	wait = 5,
	walk = 6,
}

function pathfinder.traversal(actor, from_x, from_y, x, y, z, goal)
	local land_x, land_reason = actions.vault_landing(actor, from_x, from_y, x, y, z)
	local landing = land_x and "free" or land_reason

	local damage = actor.can_perform and actor.can_perform.attackable and stats.get_current(actor, "damage") or 0
	local ret_kind, ret_cost, ret_target = "walk", 1, nil
	local blocked = false
	for _, c in ipairs(utils.footprint_offsets(actor)) do
		local kind, cost, target = cell_traversal(actor, x + c.dx, y + c.dy, z, goal, landing, damage)
		if kind == "blocked" then
			blocked = true
		elseif kind_order[kind] < kind_order[ret_kind] and cost then
			ret_kind, ret_cost, ret_target = kind, cost, target
		end
	end

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
		local kind, cost = pathfinder.traversal(actor, x, y, pos.x, pos.y, 1, goal)
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
