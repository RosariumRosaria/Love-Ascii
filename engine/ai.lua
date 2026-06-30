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

local function set_state(entity, new)
	local mind = entity.mind
	mind.state = new
	mind.target_pos = nil
	mind.target_value = 0
	mind.wander_turns = nil
	mind.impatience = 0
	mind.search_turns = nil
end

local function follow_path(entity)
	local mind = entity.mind
	local path = pathfinder.a_star({ x = entity.x, y = entity.y }, mind.target_pos, entity)
	if not path then
		return false
	end

	local step = path[2]
	if step and step.x and step.y then
		local dx = step.x - entity.x
		local dy = step.y - entity.y
		local kind, _, target = pathfinder.traversal(entity, step.x, step.y, 1, mind.target_pos)

		if kind == "attack" then
			entity.mind.impatience = 0
			actions:attack(entity, dx, dy, target)
		elseif kind == "open" then
			entity.mind.impatience = 0
			actions:interact(entity, dx, dy, target)
		elseif kind == "wait" then
			entity.mind.impatience = entity.mind.impatience + 1
			actions:wait(entity)
		else
			entity.mind.impatience = 0
			actions:move(entity, dx, dy)
		end
	end

	return true
end

local function reached_target(entity, target_pos)
	return utils.footprint_reaches(utils.footprint_offsets(entity), entity.x, entity.y, target_pos)
end

local function reached_or_stuck(entity, had_path)
	local mind = entity.mind
	return reached_target(entity, mind.target_pos) or not had_path
end

local function perceive(entity, target)
	local mind = entity.mind
	mind.can_see = false
	local sight = stats.get(entity, "sight") - stats.get(target, "stealth") --TODO stealth probably shouldn't work this way.

	if sight <= 0 then
		return false
	end

	if utils.distance_between(entity, target) < sight then
		mind.can_see = fov_handler.refresh(
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

	return mind.can_see
end

local function start_chasing(entity, target)
	set_state(entity, "chasing")
	local mind = entity.mind

	if mind.last_known then
		mind.last_heading =
			{ x = utils.sign(target.x - mind.last_known.x), y = utils.sign(target.y - mind.last_known.y) }
	end
	mind.last_known = { x = target.x, y = target.y }
	mind.target_pos = { x = target.x, y = target.y }
	mind.target_value = ai_cfg.target_value.sight
end

local function start_investigating(entity, x, y, value)
	set_state(entity, "investigating")
	local mind = entity.mind
	mind.last_known = { x = x, y = y }
	mind.target_pos = { x = x, y = y }
	mind.target_value = value
end

local function idle(entity)
	local mind = entity.mind
	local chance = math.random(1, ai_cfg.wander_chance)

	if chance == 1 then
		local tar_x = entity.x + math.random(-ai_cfg.wander_range, ai_cfg.wander_range)
		local tar_y = entity.y + math.random(-ai_cfg.wander_range, ai_cfg.wander_range)
		local map_max_x, map_max_y = map:get_max_x(), map:get_max_y()
		tar_x = utils.clamp(tar_x, 1, map_max_x)
		tar_y = utils.clamp(tar_y, 1, map_max_y)
		if tar_x ~= entity.x or tar_y ~= entity.y then
			set_state(entity, "wandering")
			mind.target_pos = { x = tar_x, y = tar_y }
			mind.target_value = ai_cfg.target_value.wander
			mind.wander_turns = ai_cfg.wander_turns
		end
	elseif chance == 2 or chance == 3 then
		local axis = math.random(1, 2)
		local step = (math.random(0, 1) * 2 - 1)
		local dx = (axis == 1) and step or 0
		local dy = (axis == 2) and step or 0
		actions:move(entity, dx, dy)
	end
end

local function wander(entity)
	local mind = entity.mind
	if mind.wander_turns and mind.wander_turns > 0 and mind.target_pos then
		if reached_target(entity, mind.target_pos) then
			set_state(entity, "idle")
			return
		end

		follow_path(entity)

		mind.wander_turns = mind.wander_turns - 1
		if mind.wander_turns <= 0 then
			set_state(entity, "idle")
		end
	end
end

local function pick_search_target(entity)
	local mind = entity.mind
	local cx, cy = mind.last_known.x, mind.last_known.y
	local spread = ai_cfg.search_radius

	if mind.last_heading then
		cx = cx + mind.last_heading.x * ai_cfg.search_lead
		cy = cy + mind.last_heading.y * ai_cfg.search_lead
		spread = ai_cfg.search_lead
		mind.last_heading = nil
	end

	local tx, ty = mind.last_known.x, mind.last_known.y
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

	mind.target_pos = { x = tx, y = ty }
	mind.target_value = ai_cfg.target_value.search
end

local function search(entity)
	local mind = entity.mind
	if not mind.search_turns or mind.search_turns <= 0 then
		set_state(entity, "idle")
		return
	end
	mind.search_turns = mind.search_turns - 1
	local had_path = follow_path(entity)

	if reached_or_stuck(entity, had_path) then
		pick_search_target(entity)
	end
end

local function investigate(entity)
	local mind = entity.mind
	if mind.target_pos then
		local had_path = follow_path(entity)
		if reached_or_stuck(entity, had_path) then
			set_state(entity, "searching")
			mind.search_turns = ai_cfg.search_turns
			mind.target_pos = { x = mind.last_known.x, y = mind.last_known.y }
			mind.target_value = ai_cfg.target_value.search
		end
	end
end

local function chase(entity)
	local mind = entity.mind
	local had_path = follow_path(entity)
	if not had_path and mind.last_known then
		start_investigating(entity, mind.last_known.x, mind.last_known.y, ai_cfg.target_value.sight)
	end
end

local function process_hearing(entity)
	local mind = entity.mind
	if mind.heard_sounds and #mind.heard_sounds > 0 then
		local loudest = nil
		for _, heard in ipairs(mind.heard_sounds) do
			if not loudest or loudest.loudness < heard.loudness then
				loudest = heard
			end
		end
		mind.heard_sounds = {}
		return loudest
	end
	return nil
end

local function enemy_turn(entity)
	local mind = entity.mind
	local loudest = process_hearing(entity)
	local heard = false
	if
		(
			mind.state == "wandering"
			or mind.state == "idle"
			or mind.state == "investigating"
			or mind.state == "searching"
		)
		and loudest
		and loudest.loudness > (mind.target_value or 0)
	then
		start_investigating(entity, loudest.sound.x, loudest.sound.y, loudest.loudness)
		heard = true
	end

	if
		(mind.state == "idle" or mind.state == "wandering")
		and utils.distance_between(entity, entities.player) > ai_cfg.activation_range
	then
		return
	end
	local targets = map:find_targets_in_range(entity, ai_cfg.activation_range)
	local saw = false
	local target = nil
	if targets then
		for _, tar in ipairs(targets) do
			saw = perceive(entity, tar.entity)
			if saw then
				target = tar.entity
				break
			end
		end
	end
	if saw then
		start_chasing(entity, target)
	elseif mind.state == "chasing" then
		if mind.last_known then
			start_investigating(entity, mind.last_known.x, mind.last_known.y, ai_cfg.target_value.sight)
		else
			set_state(entity, "idle")
		end
	end

	if mind.state == "idle" then
		idle(entity)
	elseif mind.state == "wandering" then
		wander(entity)
	elseif mind.state == "chasing" then
		chase(entity)
	elseif mind.state == "investigating" then
		investigate(entity)
	elseif mind.state == "searching" then
		search(entity)
	end

	if mind.can_see and not mind.could_see then
		effects:remove_anchored(entity, "huh")

		effects:add_from_template("alert", entity.x, entity.y, entity.z, { anchor = entity })
	elseif heard then
		effects:add_from_template("huh", entity.x, entity.y, entity.z, { anchor = entity })
	end
	mind.could_see = mind.can_see
end

function ai:take_turn(entity)
	if entity.team ~= "enemy" then
		return
	end
	enemy_turn(entity)
end

return ai
