local map = require("map.map")
local entities = require("entities.entities")
local visuals = require("visuals.visuals")
local pathfinder = require("engine.pathfinder")
local fov_handler = require("fov.fov_handler")
local engine = require("engine.engine")
local engine_utils = require("engine.engine_utils")

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

local function clamp(val, min, max)
	return math.max(min, math.min(max, val))
end

local function can_see(entity, target)
	if not entity.sight or entity.sight <= 0 then
		return false
	end

	entity.can_see = false
	if engine_utils.distance_between(entity, target) < entity.sight then
		entity.can_see = fov_handler.refresh_visibility(
			entity.x,
			entity.y,
			entity.sight,
			map:get_width(),
			map:get_height(),
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
		entity.turns_to_idle = 20
		entity.path = nil
		entity.path_index = nil
		return true
	end

	return false
end

local function idle(entity)
	if entity.type == "enemy" then
		if can_see(entity, player) then
			return
		end
		local chance = math.random(1, 5)
		if chance == 1 then
			local tar_x = entity.x + math.random(-10, 10)
			local tar_y = entity.y + math.random(-10, 10)
			local map_width, map_height = map:get_width(), map:get_height()
			tar_x = clamp(tar_x, 1, map_width)
			tar_y = clamp(tar_y, 1, map_height)
			if tar_x ~= entity.x or tar_y ~= entity.y then
				entity.state = "wandering"
				entity.target_pos = { tar_x, tar_y }
				entity.turns_to_idle = 20
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
			if can_see(entity, player) then
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
		if can_see(entity, player) then
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
