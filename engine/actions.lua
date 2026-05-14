local entities = require("entities.entities")
local effects = require("visuals.effects.effects")

local event_log = require("engine.event_log")
local map = require("map.map")
local utils = require("utils")
local statuses = require("entities.statuses")
local stats = require("entities.stats")
local inventory = require("entities.inventory")
local actions = {}

local function validate_interaction(actor, target, name)
	if not actor then
		event_log:add({ type = "action_failed", entity = "Unknown", reason = name .. " actor is nil" })
		return false
	end
	if not target then
		event_log:add({ type = "action_failed", entity = "Unknown", reason = name .. " target is nil" })
		return false
	end
	if utils.distance_between(actor, target) > 1 then
		event_log:add({ type = "action_failed", entity = target.name, reason = "Too far apart" })
		return false
	end
	return true
end

function actions:default_interact(entity, dx, dy)
	local target = entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not target then
		return false
	end
	local action = target.default_action
	if action == "interactable" and entity.allowed_actions[action] then
		return self:interact(entity, dx, dy)
	elseif action == "attackable" and entity.allowed_actions[action] then
		return self:attack(entity, dx, dy)
	elseif action == "moveable" and entity.allowed_actions[action] then
		return self:drag(entity, dx, dy)
	elseif action == "pickupable" and entity.allowed_actions[action] then
		return self:pickup(entity, dx, dy)
	end
	return false
end

function actions:pickup(entity, dx, dy)
	local target = entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not validate_interaction(entity, target, "Pickup") then
		return false
	end
	if not target.tags.pickupable then
		event_log:add({ type = "action_failed", entity = target.name, reason = "Not pickupable" })
		return false
	end

	inventory.add_item(entity, target.item.key, target.item.overrides)

	entities:remove_entity(target)
	event_log:add({ type = "entity_picked_up", entity = target.name, source = entity.name })
	return true
end

function actions:attack(entity, dx, dy)
	local target_entity = entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not validate_interaction(entity, target_entity, "Attack") then
		return false
	end
	if not entities:get_tag_entity(target_entity, "attackable") then
		event_log:add({ type = "action_failed", entity = target_entity.name, reason = "Not attackable" })
		return false
	end
	if entity.team ~= target_entity.team then
		effects:add_from_template("attack", entity.x + dx, entity.y + dy, entity.z)
		entities:apply_damage(target_entity, stats.get_stat(entity, "damage"), entity.name)
		statuses.apply_on_hit_statuses(entity, target_entity)
	end
	return true
end

function actions:interact(entity, dx, dy)
	local target_entity = entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not validate_interaction(entity, target_entity, "Interact") then
		return false
	end

	if not target_entity.tags.interactable then
		event_log:add({ type = "action_failed", entity = target_entity.name, reason = "Not interactable" })
		return false
	end
	entities:interact_with_entity(target_entity)
	return true
end

function actions:inspect(entity, dx, dy)
	local target_entity = entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not validate_interaction(entity, target_entity, "Inspect") then
		return false
	end

	entities:inspect_entity(target_entity)
end

function actions:move(entity, dx, dy)
	local tar_x = entity.x + dx
	local tar_y = entity.y + dy

	if map:is_tile_free(tar_x, tar_y, entity.z, { [entity] = true }) then
		local effect = effects:add_from_template("trail", entity.x, entity.y, entity.z)
		effect.rects[1].colors[1] = entity.effect_color or effect.rects[1].colors[1]
		entity.x = tar_x
		entity.y = tar_y
		return true
	end

	return actions:default_interact(entity, dx, dy)
end

function actions:grab(entity, dx, dy)
	return entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
end

function actions:drag(entity, dx, dy, target)
	target = target or entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not validate_interaction(entity, target, "Drag") then
		return false
	end
	if not target.tags.moveable then
		event_log:add({ type = "action_failed", entity = target.name, reason = "Target is not moveable" })
		return false
	end

	local skip = { [entity] = true, [target] = true }
	local actor_dest_x, actor_dest_y = entity.x + dx, entity.y + dy
	local target_dest_x, target_dest_y = target.x + dx, target.y + dy

	if not map:is_tile_free(actor_dest_x, actor_dest_y, entity.z, skip) then
		event_log:add({ type = "action_failed", entity = entity.name, reason = "Actor tile not free" })
		return false
	end
	if not map:is_tile_free(target_dest_x, target_dest_y, target.z, skip) then
		event_log:add({ type = "action_failed", entity = target.name, reason = "Target tile not free" })
		return false
	end

	effects:add_from_template("trail", entity.x, entity.y, entity.z)
	entity.x, entity.y = actor_dest_x, actor_dest_y
	target.x, target.y = target_dest_x, target_dest_y

	event_log:add({
		type = "entity_dragged",
		entity = target.name,
		source = entity.name,
		dest_x = target_dest_x,
		dest_y = target_dest_y,
	})

	return true
end

function actions:handle_action(entity, action)
	if not entity or not action then
		return false
	end

	local t = action.type

	if t == "move" then
		return self:move(entity, action.dx, action.dy)
	elseif t == "attack" then
		return self:attack(entity, action.dx, action.dy)
	elseif t == "interact" then
		return self:interact(entity, action.dx, action.dy)
	elseif t == "inspect" then
		return self:inspect(entity, action.dx, action.dy)
	elseif t == "grab_interaction" then
		return self:drag(entity, action.dx, action.dy, action.target)
	end

	return false
end

return actions
