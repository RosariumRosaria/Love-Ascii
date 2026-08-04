local entities = require("src.sim.entities")
local effects = require("src.visuals.effects.effects")
local event_log = require("src.engine.event_log")
local map = require("src.map.map")
local utils = require("src.utils")
local statuses = require("src.sim.statuses")
local inventory = require("src.sim.inventory")
local animation = require("src.visuals.render.animation")
local sounds = require("src.engine.sounds")
local combat = require("src.engine.combat")
local particles = require("src.visuals.particles.particles")
local game_cfg = require("src.config.game_config")
local actions = {}

--TODO: Someday this should split the validatity and targeting of an action from it's execution, so that it and pathfinder can always be in sync.

local function validate_interaction(actor, target, name, range, spam)
	range = range or 1
	if not actor then
		event_log:add({ type = "action_failed", entity = "Unknown", reason = name .. " actor is nil" })
		return false
	end
	if not target then
		event_log:add({ type = "action_failed", entity = "Unknown", reason = name .. " target is nil" })
		return false
	end

	for _, c in ipairs(utils.footprint_cells(actor)) do
		for _, cc in ipairs(utils.footprint_cells(target)) do
			if utils.distance_between(c, cc) <= range then
				return true
			end
		end
	end

	event_log:add({ type = "action_failed", entity = target, reason = "Too far apart", spam = spam })
	return false
end

local action_order = {
	attackable = 5,
	pickupable = 4,
	moveable = 3,
	vaultable = 2,
	interactable = 1,
}

local function target_priority(entity)
	return entity.interact_priority or 0
end

local function pick_target(x, y, z, tag)
	local candidates = entities.get_list_at(x, y, z)
	if not candidates then
		return nil
	end

	local best
	for _, candidate in ipairs(candidates) do
		if utils.get_tag(candidate, tag) and (not best or target_priority(candidate) > target_priority(best)) then
			best = candidate
		end
	end
	return best
end

local action_cost = game_cfg.action_cost

local function assign_cost(entity, action_type)
	entity.action_cost = action_cost[action_type]
end

local function record_trail(entity)
	animation.spawn_pending_trail(entity)
	animation.set_pending_trail(entity)
end

local function spawn_burst(entity, type_name, count, opts)
	local cx, cy = utils.get_center_of_footprint(entity)
	particles:burst(entity.x + cx, entity.y + cy, entity.z, type_name, count, opts)
end

local function resolve_target(actor, dx, dy, tag, name, target)
	target = target or pick_target(actor.x + dx, actor.y + dy, actor.z, tag)
	if not validate_interaction(actor, target, name) then
		return nil
	end
	if not utils.get_tag(target, tag) then
		event_log:add({ type = "action_failed", entity = target, reason = "Not " .. tag })
		return nil
	end
	return target
end

function actions:default_interact(entity, dx, dy)
	local targets = entities.get_list_at(entity.x + dx, entity.y + dy, entity.z)
	if not targets or #targets == 0 then
		return false
	end

	local target
	for _, tar in ipairs(targets) do
		if tar.default_action and (entity.can_perform and entity.can_perform[tar.default_action]) then
			local rank = action_order[tar.default_action]
			local best_rank = target and action_order[target.default_action]
			if
				not target
				or rank > best_rank
				or (rank == best_rank and target_priority(tar) > target_priority(target))
			then
				target = tar
			end
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
	elseif action == "vaultable" then
		return self:vault(entity, dx, dy, target)
	end
	return false
end

function actions:place(entity, dx, dy, item)
	local target_x = entity.x + dx
	local target_y = entity.y + dy

	if not map:is_tile_free(target_x, target_y, entity.z, { [entity] = true }) then
		event_log:add({ type = "action_failed", entity = entity, reason = "Tile not free" })
		return false
	end

	entities.convert_item_to_pickup(target_x, target_y, entity.z, item)

	inventory.remove(entity, item)
	assign_cost(entity, "place")
	event_log:add({ type = "entity_placed", entity = item, source = entity })
	return true
end

function actions:use_selected(entity, dx, dy)
	local item = inventory.get_selected(entity)
	if not item then
		event_log:add({ type = "action_failed", entity = entity, reason = "No item selected" })
		return false
	end

	if item.slot then
		if inventory.is_equipped(entity, item) then
			return self:unequip_item(entity, item)
		end
		return self:equip_item(entity, item)
	end

	if item.on_use then
		return self:use_item(entity, item, dx, dy)
	end

	event_log:add({
		type = "action_failed",
		entity = entity,
		reason = "Item '" .. item.name .. "' cannot be used",
	})
	return false
end

function actions:equip_item(entity, item)
	local displaced = inventory.equip(entity, item)
	if displaced then
		event_log:add({
			type = "item_unequipped",
			entity = entity,
			item = displaced.name,
			slot = item.slot,
		})
	end
	assign_cost(entity, "equip")
	event_log:add({ type = "item_equipped", entity = entity, item = item, slot = item.slot })
	return true
end

function actions:unequip_item(entity, item)
	inventory.unequip(entity, item.slot)
	assign_cost(entity, "unequip")
	event_log:add({ type = "item_unequipped", entity = entity, item = item, slot = item.slot })
	return true
end

function actions:use_item(entity, item, dx, dy)
	if item.charges and item.charges <= 0 then
		event_log:add({ type = "action_failed", entity = entity, reason = "Out of charges" })
		return false
	end

	local target = entity
	if item.on_use.targets then
		target = entities.get_with_tag(entity.x + dx, entity.y + dy, entity.z, item.on_use.target_tag)
		if not validate_interaction(entity, target, "Use Item") then
			return false
		end
		if item.on_use.apply_status and statuses.find(target, item.on_use.apply_status) then
			event_log:add({
				type = "action_failed",
				entity = (target and target.name) or "",
				reason = "Already " .. item.on_use.apply_status,
			})
			return false
		end
	end

	if item.on_use.clear_status and not statuses.has_tag(target, item.on_use.clear_status) then
		event_log:add({
			type = "action_failed",
			entity = (target and target.name) or "",
			reason = "not " .. item.on_use.clear_status,
		})
		return false
	end

	if item.on_use.apply_status then
		statuses.add_from_template(target, item.on_use.apply_status, nil, item)
	end

	if item.on_use.clear_status then
		statuses.remove_with_tag(target, item.on_use.clear_status)
	end

	assign_cost(entity, "use_item")
	event_log:add({ type = "item_used", entity = entity, item = item })
	if item.on_use.burst then
		spawn_burst(target, item.on_use.burst.type, item.on_use.burst.count or 1, {
			spread = item.on_use.burst.spread or 2,
			smin = item.on_use.burst.smin or 1,
			smax = item.on_use.burst.smax or 2,
		})
	end

	if inventory.use_charge(entity, item) then
		event_log:add({ type = "item_consumed", entity = entity, item = item })
	end
	return true
end

function actions:place_selected(entity, dx, dy)
	local item = inventory.get_selected(entity)
	if not item then
		event_log:add({ type = "action_failed", entity = entity, reason = "No item selected" })
		return false
	end
	return actions:place(entity, dx, dy, item)
end

function actions:pickup(entity, dx, dy, target)
	target = resolve_target(entity, dx, dy, "pickupable", "Pickup", target)
	if not target then
		return false
	end

	inventory.add(entity, target.item)

	entities.remove(target)
	assign_cost(entity, "pickup")
	event_log:add({ type = "entity_picked_up", entity = target, source = entity })
	return true
end

function actions:attack(entity, dx, dy, target_entity)
	target_entity = resolve_target(entity, dx, dy, "attackable", "Attack", target_entity)
	if not target_entity or not entity.can_perform or not entity.can_perform.attackable then
		return false
	end
	if entity.team ~= target_entity.team then
		assign_cost(entity, "attack")

		animation.add_bump(entity, target_entity.x, target_entity.y)
		combat.strike(entity, target_entity, { context = "melee" })
		sounds.emit(combat.build_hit_sound(entity, target_entity, nil, "melee"))
	end
	return true
end

function actions:can_ranged_attack(entity, target_x, target_y, target_entity, spam)
	local weapon = inventory.get_equipped(entity, "mainhand")

	if not weapon or not weapon.ranged then
		return false
	end
	if not entity.can_perform or not entity.can_perform.attackable then
		return false
	end

	target_entity = target_entity or entities.get_with_tag(target_x, target_y, entity.z, "attackable")
	if not validate_interaction(entity, target_entity, "Ranged_Attack", weapon.range, spam) then
		return false
	end
	if not utils.get_tag(target_entity, "attackable") then
		event_log:add({ type = "action_failed", entity = target_entity, reason = "Not attackable", spam = spam })
		return false
	end
	if utils.get_tag(weapon, "requires_ammo") and not inventory.get_ammo(entity) then
		event_log:add({ type = "action_failed", entity = entity, reason = "Out of ammo", spam = spam })
		return false
	end
	if entity.team == target_entity.team then
		event_log:add({ type = "action_failed", entity = entity, reason = "Invalid target", spam = spam })
		return false
	end
	return { weapon = weapon, target_entity = target_entity }
end

function actions:ranged_attack(entity, target_x, target_y, target_entity, validated)
	local attack_ret = validated or self:can_ranged_attack(entity, target_x, target_y, target_entity)

	if not attack_ret then
		return false
	end

	target_entity = attack_ret.target_entity
	local weapon = attack_ret.weapon

	assign_cost(entity, "ranged_attack")

	local ammo = inventory.equip_ammo(entity, weapon)

	if ammo then
		if ammo.break_chance and love.math.random() >= ammo.break_chance then
			local ammo_copy = utils.deep_copy(ammo)
			ammo_copy.charges = 1
			entities.convert_item_to_pickup(target_entity.x, target_entity.y, target_entity.z, ammo_copy)
		end
		inventory.use_charge(entity, ammo)
	end

	local outcome = combat.strike(entity, target_entity, {
		context = "ranged",
		weapon = weapon,
		defer_feedback = true,
	})
	local shot_sound = combat.build_hit_sound(entity, target_entity, weapon)
	shot_sound.defer_ring = true
	local player_heard = sounds.emit(shot_sound)

	local projectile = effects:add_from_template("projectile", entity.x, entity.y, entity.z)
	projectile.params.from = { x = entity.x, y = entity.y }
	projectile.params.to = target_entity
	projectile.params.duration = utils.distance_between(projectile.params.from, projectile.params.to)
		/ projectile.params.speed

	projectile.params.on_arrive = function()
		combat.play_hit_feedback(entity, target_entity, outcome)
		sounds.spawn_ring(combat.build_hit_sound(entity, target_entity, weapon), player_heard)
	end

	return true
end

function actions:interact(entity, dx, dy, target_entity)
	target_entity = resolve_target(entity, dx, dy, "interactable", "Interact", target_entity)
	if not target_entity then
		return false
	end

	if utils.get_tag(target_entity, "pickupable") then
		return self:pickup(entity, dx, dy, target_entity)
	end

	if not statuses.can_be_interacted(target_entity) then
		event_log:add({ type = "action_failed", entity = target_entity, reason = "Interaction blocked" })
		return false
	end
	if entities.interact(target_entity) then
		assign_cost(entity, "interact")
		return true
	end
	return false
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

	if map:is_footprint_free(tar_x, tar_y, entity.z, entity) then
		assign_cost(entity, "move")
		record_trail(entity)
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

-- TODO: fragile, doesn't account for bigger entities (either an entity
-- vaulting a big entity or a big entity vaulting a small entity)
function actions.vault_landing(actor, from_x, from_y, x, y, z, target)
	if not (actor.can_perform and actor.can_perform.vaultable) or actor.footprint then
		return nil, "incapable"
	end
	if target and target.footprint then
		return nil, "incapable"
	end
	local dx, dy = x - from_x, y - from_y
	if dx == 0 and dy == 0 then
		return nil, "incapable"
	end
	local land_x, land_y = x + dx, y + dy
	if not map:is_footprint_free(land_x, land_y, z, actor) then
		return nil, "occupied"
	end
	return land_x, land_y
end

function actions:vault(entity, dx, dy, target)
	target = resolve_target(entity, dx, dy, "vaultable", "Vault", target)
	if not target then
		return false
	end

	local land_x, land_y =
		actions.vault_landing(entity, entity.x, entity.y, entity.x + dx, entity.y + dy, entity.z, target)
	if not land_x then
		event_log:add({ type = "action_failed", entity = entity, reason = "Target not free" })
		return false
	end

	assign_cost(entity, "vault")
	record_trail(entity)
	entities.move_to(entity, land_x, land_y)

	animation.add_vault(entity, 2)
	sounds.emit({
		x = entity.x,
		y = entity.y,
		z = entity.z,
		volume = 8,
		reach = 12,
		description = "a thud",
		source = entity,
	}) --TODO: Someday this should tie into stealth or something
	spawn_burst(entity, "dust", 4, {
		spread = 4,
		smin = 1,
		smax = 3,
	})
	return true
end

function actions:grab(entity, dx, dy)
	return entities.get_first(entity.x + dx, entity.y + dy, entity.z)
end

function actions:drag(entity, dx, dy, target)
	target = resolve_target(entity, dx, dy, "moveable", "Drag", target)
	if not target then
		return false
	end

	local skip = { [entity] = true, [target] = true }
	local actor_dest_x, actor_dest_y = entity.x + dx, entity.y + dy
	local target_dest_x, target_dest_y = target.x + dx, target.y + dy

	if not map:is_tile_free(actor_dest_x, actor_dest_y, entity.z, skip) then
		event_log:add({ type = "action_failed", entity = entity, reason = "Actor tile not free" })
		return false
	end
	if not map:is_tile_free(target_dest_x, target_dest_y, target.z, skip) then
		event_log:add({ type = "action_failed", entity = target, reason = "Target tile not free" })
		return false
	end

	assign_cost(entity, "drag")
	record_trail(entity)
	entities.move_to(entity, actor_dest_x, actor_dest_y)
	entities.move_to(target, target_dest_x, target_dest_y)

	spawn_burst(target, "dust", 2, {
		spread = 4,
		smin = 1,
		smax = 3,
	})

	event_log:add({
		type = "entity_dragged",
		entity = target,
		source = entity,
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
	assign_cost(entity, "wait")
	event_log:add({ type = "entity_waited", entity = entity, spam = true })
	return true
end

function actions:transfer_item(entity, from, to, item)
	item = item or inventory.get_selected(from)
	if item then
		if inventory.transfer(from, to, item) then
			assign_cost(entity, "transfer_item")
			return true
		end
	end
	return false
end

function actions:handle_action(entity, action)
	if not entity or not action then
		return false
	end

	local t = action.type

	if t == "move" then
		return self:move(entity, action.dx, action.dy)
	elseif t == "vault" then
		return self:vault(entity, action.dx, action.dy, action.target)
	elseif t == "attack" then
		return self:attack(entity, action.dx, action.dy)
	elseif t == "ranged_attack" then
		return self:ranged_attack(entity, action.target_x, action.target_y)
	elseif t == "interact" then
		return self:interact(entity, action.dx, action.dy)
	elseif t == "inspect" then
		return self:inspect(entity, action.dx, action.dy)
	elseif t == "equip_item" then
		return self:equip_item(entity, action.item)
	elseif t == "grab_interaction" then
		return self:drag(entity, action.dx, action.dy, action.target)
	elseif t == "use_selected" then
		return self:use_selected(entity, action.dx, action.dy)
	elseif t == "place_selected" then
		return self:place_selected(entity, action.dx, action.dy)
	elseif t == "transfer_item" then
		return self:transfer_item(entity, action.from, action.to)
	elseif t == "wait" then
		return self:wait(entity)
	end

	return false
end

return actions
