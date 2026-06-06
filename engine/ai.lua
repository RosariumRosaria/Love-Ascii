local map = require("map.map")
local entities = require("entities.entities")
local effects = require("visuals.effects.effects")
local pathfinder = require("engine.pathfinder")
local fov_handler = require("fov.visibility")
local actions = require("engine.actions")
local utils = require("utils")
local ai_cfg = require("config.ai_config")
local event_log = require("engine.event_log")
local stats = require("stats.stats")

local ai = {}
--[[ TODO, At some point the flow should probably be more like
  -Entity gets list of entities in area
  -Entity has a list of states it can have, and maybe overrides for what those states can do
  -IE, basic enemies would get a list of all entities near them,
  filter to those they can see,
  then those they can see and are not also enemies,
  then those they can pathfind too
  Then pick based on some weights to be a target
]]

local function step_toward(entity, step)
	if step and step.x and step.y then
		local dx = step.x - entity.x
		local dy = step.y - entity.y
		local kind = pathfinder.traversal(entity, step.x, step.y, 1, entity.target_pos)
		if kind == "attackable" then
			actions:attack(entity, dx, dy)
			return false
		elseif kind == "open" then
			actions:interact(entity, dx, dy)
			return false
		elseif actions:move(entity, dx, dy) then
			return true
		end
	end

	return false
end

local function can_see(entity, target)
	local sight = stats.get_stat(entity, "sight") - stats.get_stat(target, "stealth") --TODO stealth probably shouldn't work this way.

	if sight <= 0 then
		return false
	end

	entity.can_see = false
	if utils.distance_between(entity, target) < sight then
		entity.can_see = fov_handler.refresh_visibility(
			entity.x,
			entity.y,
			sight,
			map:get_max_x(),
			map:get_max_y(),
			map:get_tiles(),
			nil,
			false,
			target.x,
			target.y
		)
	end

	if entity.can_see then
		entity.state = "chasing"
		entity.target_entity = target
		if entity.last_seen then
			entity.last_heading =
				{ x = utils.sign(target.x - entity.last_seen.x), y = utils.sign(target.y - entity.last_seen.y) }
		end

		entity.last_seen = { x = target.x, y = target.y }
		entity.target_pos = { x = target.x, y = target.y }
		entity.path = nil
		entity.path_index = nil
		return true
	end

	return false
end

local function idle(entity)
	if entity.team == "enemy" then
		if can_see(entity, entities.player) then --TODO This is ugly, treats the player as special
			return
		end
		local chance = math.random(1, ai_cfg.wander_chance)

		if chance == 1 then
			local tar_x = entity.x + math.random(-ai_cfg.wander_range, ai_cfg.wander_range)
			local tar_y = entity.y + math.random(-ai_cfg.wander_range, ai_cfg.wander_range)
			local map_max_x, map_max_y = map:get_max_x(), map:get_max_y()
			tar_x = utils.clamp(tar_x, 1, map_max_x)
			tar_y = utils.clamp(tar_y, 1, map_max_y)
			if tar_x ~= entity.x or tar_y ~= entity.y then
				entity.state = "wandering"
				entity.target_pos = { x = tar_x, y = tar_y }
				entity.wander_turns = ai_cfg.wander_turns
			end
		elseif chance == 2 or chance == 3 then
			local axis = math.random(1, 2)
			local step = (math.random(0, 1) * 2 - 1)
			local dx = (axis == 1) and step or 0
			local dy = (axis == 2) and step or 0
			actions:move(entity, dx, dy)
		end
	end
end

local function wander(entity)
	if entity.team == "enemy" then
		if entity.wander_turns and entity.wander_turns > 0 and entity.target_pos then
			if can_see(entity, entities.player) then
				entity.path = nil
				entity.path_index = nil
				return
			end

			if entity.x == entity.target_pos.x and entity.y == entity.target_pos.y then
				entity.state = "idle"
				entity.target_pos = nil
				entity.path = nil
				entity.path_index = nil
				return
			end

			entity.path = pathfinder.a_star({ x = entity.x, y = entity.y }, entity.target_pos, entity)
			if entity.path then
				step_toward(entity, entity.path[2])
			end

			entity.wander_turns = entity.wander_turns - 1
			if entity.wander_turns <= 1 then
				effects:add_from_template("ping", entity.target_pos.x, entity.target_pos.y, 1)
				entity.state = "idle"
				entity.target_pos = nil
				entity.path = nil
				entity.path_index = nil
			end
		end
	end
end

local function pick_search_target(entity)
	local cx, cy = entity.last_seen.x, entity.last_seen.y
	local spread = ai_cfg.search_radius

	if entity.last_heading then
		cx = cx + entity.last_heading.x * ai_cfg.search_lead
		cy = cy + entity.last_heading.y * ai_cfg.search_lead
		spread = ai_cfg.search_lead
		entity.last_heading = nil
	end

	local tx, ty = entity.last_seen.x, entity.last_seen.y
	for _ = 1, ai_cfg.search_attempts do
		local angle = math.random() * 2 * math.pi
		local radius = spread * math.sqrt(math.random())
		local rx = math.floor(cx + radius * math.cos(angle) + 0.5)
		local ry = math.floor(cy + radius * math.sin(angle) + 0.5)
		if map:walkable(rx, ry, 1) then
			tx, ty = rx, ry
			break
		end
	end

	entity.target_pos = { x = tx, y = ty }
	effects:add_from_template("ping", entity.target_pos.x, entity.target_pos.y, 1)
end

local function search(entity)
	if not entity.search_turns or entity.search_turns <= 0 then
		entity.state = "idle"
		return
	end
	entity.search_turns = entity.search_turns - 1
	entity.path = pathfinder.a_star({ x = entity.x, y = entity.y }, entity.target_pos, entity)
	entity.path_index = 2
	if entity.path and step_toward(entity, entity.path[entity.path_index]) then
		entity.path_index = entity.path_index + 1
	end
	if (entity.x == entity.target_pos.x and entity.y == entity.target_pos.y) or not entity.path then
		pick_search_target(entity)
	end
end
local function investigate(entity)
	if entity.target_pos then
		entity.path = pathfinder.a_star({ x = entity.x, y = entity.y }, entity.target_pos, entity)
		entity.path_index = 2
		if entity.x == entity.target_pos.x and entity.y == entity.target_pos.y or not entity.path then
			entity.state = "searching"
			entity.search_turns = ai_cfg.search_turns
			entity.target_pos = { x = entity.last_seen.x, y = entity.last_seen.y }
		elseif step_toward(entity, entity.path[entity.path_index]) then
			entity.path_index = entity.path_index + 1
		end
	end
end

local function chase(entity)
	entity.path = pathfinder.a_star({ x = entity.x, y = entity.y }, entity.target_pos, entity)
	entity.path_index = 2
	if entity.path and step_toward(entity, entity.path[entity.path_index]) then
		entity.path_index = entity.path_index + 1
	end
end

local function enemy_turn(entity)
	if
		(entity.state == "idle" or entity.state == "wandering")
		and utils.distance_between(entity, entities.player) > ai_cfg.activation_range
	then
		return
	end

	local saw = can_see(entity, entities.player)
	if not saw and entity.state == "chasing" then
		entity.state = "investigating"
	end

	if entity.state == "idle" then
		idle(entity)
	elseif entity.state == "wandering" then
		wander(entity)
	elseif entity.state == "chasing" then
		chase(entity)
	elseif entity.state == "investigating" then
		investigate(entity)
	elseif entity.state == "searching" then
		search(entity)
	end

	if entity.can_see and not entity.could_see then
		effects:add_from_template("alert", entity.x, entity.y, entity.z, { anchor = entity })
	end
	entity.could_see = entity.can_see
end

function ai:take_turn(entity)
	if entity.team == "enemy" then
		enemy_turn(entity)
	end
end

return ai
