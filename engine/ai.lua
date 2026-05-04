local map = require("map.map")
local entities = require("entities.entities")
local visuals = require("visuals.effects")
local pathfinder = require("engine.pathfinder")
local fov_handler = require("fov.visibility")
local engine = require("engine.actions")
local engine_utils = require("engine.utils")
local utils = require("utils")
local ai_cfg = require("config.ai_config")

local ai_handler = {}
--[[ TODO, At some point the flow should probably be more like
  -Entity gets list of entities in area
  -Entity has a list of states it can have, and maybe overrides for what those states can do
  -IE, basic enemies would get a list of all entities near them,
  filter to those they can see,
  then those they can see and are not also enemies,
  then those they can pathfind too
  Then pick based on some waits to be a target
]]

local function can_see(entity, target)
	if not entity.stats.sight or entity.stats.sight.sight <= 0 then
		return false
	end

	entity.can_see = false
	if engine_utils.distance_between(entity, target) < entity.stats.sight.sight then
		entity.can_see = fov_handler.refresh_visibility(
			entity.x,
			entity.y,
			entity.stats.sight.sight,
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
		entity.target_pos = { target.x, target.y }
		entity.turns_to_idle = ai_cfg.turns_to_idle
		entity.path = nil
		entity.path_index = nil
		return true
	end

	return false
end

local function idle(entity)
	if entity.type == "enemy" then
		if can_see(entity, entities.player) then --This is ugly, treats the player as special
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
				entity.target_pos = { tar_x, tar_y }
				entity.turns_to_idle = ai_cfg.turns_to_idle
			end
		elseif chance == 2 or chance == 3 then
			local axis = math.random(1, 2)
			local step = (math.random(0, 1) * 2 - 1)
			local dx = (axis == 1) and step or 0
			local dy = (axis == 2) and step or 0
			engine:move(entity, dx, dy)
		end
	end
end

local function wander(entity)
	if entity.type == "enemy" then
		if entity.turns_to_idle and entity.turns_to_idle > 0 and entity.target_pos then
			if can_see(entity, entities.player) then
				entity.path = nil
				entity.path_index = nil
				return
			end

			if entity.x == entity.target_pos[1] and entity.y == entity.target_pos[2] then
				entity.state = "idle"
				entity.target_pos = nil
				entity.path = nil
				entity.path_index = nil
				return
			end

			entity.path = pathfinder.a_star({ entity.x, entity.y }, entity.target_pos)
			if entity.path then
				local step = entity.path[2]
				if step and step[1] and step[2] then
					local dx = step[1] - entity.x
					local dy = step[2] - entity.y
					engine:move(entity, dx, dy)
				end
			end

			entity.turns_to_idle = entity.turns_to_idle - 1
			if entity.turns_to_idle <= 1 then
				visuals:add_from_template("ping", entity.target_pos[1], entity.target_pos[2], 1)
				entity.state = "idle"
				entity.target_pos = nil
				entity.path = nil
				entity.path_index = nil
			end
		end
	end
end

local function chase(entity)
	if entity.turns_to_idle and entity.turns_to_idle > 0 and entity.target_pos then
		if can_see(entity, entities.player) then
			entity.path = pathfinder.a_star({ entity.x, entity.y }, entity.target_pos)
			entity.path_index = 2
		end

		if entity.path and entity.path_index then
			if entity.path_index > #entity.path then
				visuals:add_from_template("ping", entity.target_pos[1], entity.target_pos[2], 1)
				entity.state = "idle"
				entity.target_pos = nil
				return
			end

			local step = entity.path[entity.path_index]
			if step and step[1] and step[2] then
				local dx = step[1] - entity.x
				local dy = step[2] - entity.y
				if engine:move(entity, dx, dy) then
					entity.path_index = entity.path_index + 1
				end
			end
		end

		entity.turns_to_idle = entity.turns_to_idle - 1
		if entity.turns_to_idle <= 1 then
			visuals:add_from_template("ping", entity.target_pos[1], entity.target_pos[2], 1)
			entity.state = "idle"
			entity.target_pos = nil
			entity.path = nil
			entity.path_index = nil
		end
	end
end

local function process_enemy(entity)
	if entity.state == "idle" then
		idle(entity)
	elseif entity.state == "wandering" then
		wander(entity)
	elseif entity.state == "chasing" then
		chase(entity)
	end

	if entity.can_see and not entity.could_see then
		visuals:add_from_template("alert", entity.x, entity.y, entity.z, { anchor = entity })
	end

	entity.could_see = entity.can_see
end

function ai_handler.process_turn()
	local entity_list = entities:get_entity_list()
	for _, entity in ipairs(entity_list) do
		if entity.type == "enemy" then
			process_enemy(entity)
		end
	end
end

return ai_handler
