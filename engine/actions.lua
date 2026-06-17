local entities = require("entities.entities")
local effects = require("visuals.effects.effects")
local aim = require("engine.aim")
local event_log = require("engine.event_log")
local map = require("map.map")
local utils = require("utils")
local statuses = require("statuses.statuses")
local stats = require("stats.stats")
local inventory = require("items.inventory")
local animation = require("visuals.render.animation")
local sounds = require("engine.sounds")
local vitals = require("engine.vitals")
local actions = {}

local function validate_interaction(actor, target, name, range)
	range = range or 1
	if not actor then
		event_log:add({ type = "action_failed", entity = "Unknown", reason = name .. " actor is nil" })
		return false
	end
	if not target then
		event_log:add({ type = "action_failed", entity = "Unknown", reason = name .. " target is nil" })
		return false
	end
	if utils.distance_between(actor, target) > range then
		event_log:add({ type = "action_failed", entity = target.name, reason = "Too far apart" })
		return false
	end
	return true
end

local action_order = {
	attackable = 4,
	pickupable = 3,
	moveable = 2,
	interactable = 1,
}

function actions:default_interact(entity, dx, dy)
	local targets = entities.get_list_at(entity.x + dx, entity.y + dy, entity.z)
	if not targets or #targets == 0 then
		return false
	end

	local target
	for _, tar in ipairs(targets) do
		if
			tar.default_action
			and (entity.allowed_actions and entity.allowed_actions[tar.default_action])
			and (not target or (action_order[tar.default_action] > action_order[target.default_action]))
		then
			target = tar
		end
	end

	if not target then
		return false
	end

	local action = target.default_action

	if action == "interactable" then
		return self:interact(entity, dx, dy, target)
	elseif action == "attackable" then
		return self:attack(entity, dx, dy, target)
	elseif action == "moveable" then
		return self:drag(entity, dx, dy, target)
	elseif action == "pickupable" then
		return self:pickup(entity, dx, dy, target)
	end
	return false
end

function actions:place(entity, dx, dy, item)
	local target_x = entity.x + dx
	local target_y = entity.y + dy

	if not map:is_tile_free(target_x, target_y, entity.z, { [entity] = true }) then
		event_log:add({ type = "action_failed", entity = entity.name, reason = "Tile not free" })
		return false
	end

	entities.convert_item_to_pickup(target_x, target_y, entity.z, item)

	inventory.remove(entity, item)
	event_log:add({ type = "entity_placed", entity = item.name, source = entity.name })
	return true
end

function actions:use_selected(entity)
	local item = inventory.get_selected(entity)
	if not item then
		event_log:add({ type = "action_failed", entity = entity.name, reason = "No item selected" })
		return false
	end

	if item.slot then
		if inventory.is_equipped(entity, item) then
			return self:unequip_item(entity, item)
		end
		return self:equip_item(entity, item)
	end

	if item.on_use then
		return self:use_item(entity, item)
	end

	event_log:add({
		type = "action_failed",
		entity = entity.name,
		reason = "Item '" .. item.name .. "' cannot be used",
	})
	return false
end

function actions:equip_item(entity, item)
	local displaced = inventory.equip(entity, item)
	if displaced then
		event_log:add({
			type = "item_unequipped",
			entity = entity.name,
			item = displaced.name,
			slot = item.slot,
		})
	end
	event_log:add({ type = "item_equipped", entity = entity.name, item = item.name, slot = item.slot })
	return true
end

function actions:unequip_item(entity, item)
	inventory.unequip(entity, item.slot)
	event_log:add({ type = "item_unequipped", entity = entity.name, item = item.name, slot = item.slot })
	return true
end

function actions:use_item(entity, item)
	if item.on_use.apply_status then
		statuses.add_from_template(entity, item.on_use.apply_status, nil, item)
	end
	event_log:add({ type = "item_used", entity = entity.name, item = item.name })
	if inventory.use_charge(item) then
		inventory.remove(entity, item)
		event_log:add({ type = "item_consumed", entity = entity.name, item = item.name })
	end
	return true
end

function actions:place_selected(entity, dx, dy)
	local item = inventory.get_selected(entity)
	if not item then
		event_log:add({ type = "action_failed", entity = entity.name, reason = "No item selected" })
		return false
	end
	return actions:place(entity, dx, dy, item)
end

function actions:pickup(entity, dx, dy, target)
	target = target or entities.get_with_tag(entity.x + dx, entity.y + dy, entity.z, "pickupable")
	if not validate_interaction(entity, target, "Pickup") then
		return false
	end
	if not target.tags.pickupable then
		event_log:add({ type = "action_failed", entity = target.name, reason = "Not pickupable" })
		return false
	end

	inventory.add(entity, target.item)

	entities.remove(target)
	event_log:add({ type = "entity_picked_up", entity = target.name, source = entity.name })
	return true
end

function actions:attack(entity, dx, dy, target_entity)
	local weapon = inventory.get_equipped(entity, "mainhand")
	target_entity = target_entity or entities.get_with_tag(entity.x + dx, entity.y + dy, entity.z, "attackable")
	if not validate_interaction(entity, target_entity, "Attack") then
		return false
	end
	if not entities.get_tag(target_entity, "attackable") then
		event_log:add({ type = "action_failed", entity = target_entity.name, reason = "Not attackable" })
		return false
	end
	if entity.team ~= target_entity.team then
		effects:add_from_template("attack", entity.x + dx, entity.y + dy, entity.z)
		animation.add_bump(entity, target_entity.x, target_entity.y)
		vitals.apply_damage(target_entity, stats.get(entity, "damage", "melee"), entity.name)
		statuses.on_hit(entity, target_entity)
		sounds.emit({
			x = target_entity.x,
			y = target_entity.y,
			z = entity.z,
			volume = (weapon and weapon.volume) or entity.attack_volume or 6,
			reach = 12,
			description = (weapon and weapon.sound) or entity.attack_sound or "a thwack",
			source = entity,
		})
	end
	return true
end

function actions:ranged_attack(entity, target_x, target_y, target_entity)
	local weapon = aim.weapon --TODO: this doesn't work for anything but the player
	if not weapon then
		return false
	end

	target_entity = target_entity or entities.get_with_tag(target_x, target_y, entity.z, "attackable")
	if not validate_interaction(entity, target_entity, "Ranged_Attack", weapon.range) then
		return false
	end
	if (weapon.charges or 0) <= 0 then
		event_log:add({ type = "action_failed", entity = entity.name, reason = "Out of ammo" })
		return false
	end
	if entity.team == target_entity.team then
		return true
	end

	inventory.use_charge(weapon)
	effects:add_from_template("attack", target_x, target_y, entity.z)
	vitals.apply_damage(target_entity, stats.get(entity, "damage"), entity.name)
	statuses.on_hit(entity, target_entity) --TODO should on hit apply from ranged
	sounds.emit({
		x = target_x,
		y = target_y,
		z = entity.z,
		volume = weapon.volume or 6,
		reach = 10,
		description = weapon.sound or "a thwack",
		source = entity,
	})
	return true
end

function actions:interact(entity, dx, dy, target_entity)
	target_entity = target_entity or entities.get_with_tag(entity.x + dx, entity.y + dy, entity.z, "interactable")
	if not validate_interaction(entity, target_entity, "Interact") then
		return false
	end

	if not target_entity.tags.interactable then
		event_log:add({ type = "action_failed", entity = target_entity.name, reason = "Not interactable" })
		return false
	end
	entities.interact(target_entity)
	return true
end

function actions:inspect(entity, dx, dy)
	local target_entity = entities.get_first(entity.x + dx, entity.y + dy, entity.z)
	if not validate_interaction(entity, target_entity, "Inspect") then
		return false
	end

	entities.inspect(target_entity)
end

function actions:move(entity, dx, dy)
	local tar_x = entity.x + dx
	local tar_y = entity.y + dy

	if map:is_tile_free(tar_x, tar_y, entity.z, { [entity] = true }) then
		animation.spawn_pending_trail(entity)
		entity.pending_trail = { x = entity.x, y = entity.y, z = entity.z, color = entity.appearance.effect_color }
		entities.move_to(entity, tar_x, tar_y)
		sounds.emit({
			x = entity.x,
			y = entity.y,
			z = entity.z,
			volume = 4,
			reach = 12,
			description = "footsteps",
			source = entity,
		}) --TODO: Someday this should tie into stealth or something
		return true
	end

	return actions:default_interact(entity, dx, dy)
end

function actions:grab(entity, dx, dy)
	return entities.get_first(entity.x + dx, entity.y + dy, entity.z)
end

function actions:drag(entity, dx, dy, target)
	target = target or entities.get_with_tag(entity.x + dx, entity.y + dy, entity.z, "moveable")
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

	animation.spawn_pending_trail(entity)
	entity.pending_trail = { x = entity.x, y = entity.y, z = entity.z, color = entity.appearance.effect_color }
	entities.move_to(entity, actor_dest_x, actor_dest_y)
	entities.move_to(target, target_dest_x, target_dest_y)

	event_log:add({
		type = "entity_dragged",
		entity = target.name,
		source = entity.name,
		dest_x = target_dest_x,
		dest_y = target_dest_y,
	})

	sounds.emit({
		x = target_dest_x,
		y = target_dest_y,
		z = entity.z,
		volume = 16,
		reach = 16,
		description = "a thud",
		source = entity,
	}) --TODO: Someday this should tie into a weight system (could also effect stamina, how long it would take etc)

	return true
end

function actions:wait(entity)
	event_log:add({ type = "entity_waited", entity = entity.name })
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
	elseif t == "ranged_attack" then
		return self:ranged_attack(entity, action.target_x, action.target_y)
	elseif t == "interact" then
		return self:interact(entity, action.dx, action.dy)
	elseif t == "inspect" then
		return self:inspect(entity, action.dx, action.dy)
	elseif t == "grab_interaction" then
		return self:drag(entity, action.dx, action.dy, action.target)
	elseif t == "use_selected" then
		return self:use_selected(entity)
	elseif t == "place_selected" then
		return self:place_selected(entity, action.dx, action.dy)
	elseif t == "wait" then
		return self:wait(entity)
	end

	return false
end

return actions
