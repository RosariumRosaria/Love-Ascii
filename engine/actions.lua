local entities = require("entities.entities")
local effects = require("visuals.effects.effects")
local event_log = require("engine.event_log")
local map = require("map.map")
local utils = require("utils")
local statuses = require("statuses.statuses")
local stats = require("stats.stats")
local inventory = require("items.inventory")
local animation = require("visuals.render.animation")
local sounds = require("engine.sounds")
local vitals = require("engine.vitals")
local particles = require("visuals.particles.particles")
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

	for _, c in ipairs(utils.footprint_cells(actor)) do
		for _, cc in ipairs(utils.footprint_cells(target)) do
			if utils.distance_between(c, cc) <= range then
				return true
			end
		end
	end

	event_log:add({ type = "action_failed", entity = target.name, reason = "Too far apart" })
	return false
end

local action_order = {
	attackable = 4,
	pickupable = 3,
	moveable = 2,
	interactable = 1,
}

local action_cost = {
	move = 1,
	attack = 1.25,
	ranged_attack = 1.25,
	interact = 1,
	pickup = 1,
	place = 1,
	drag = 2,
	use_item = 1,
	equip = 1,
	unequip = 1,
	wait = 1,
}

local function assign_cost(entity, action_type)
	entity.action_cost = action_cost[action_type]
end

local function record_trail(entity)
	animation.spawn_pending_trail(entity)
	animation.set_pending_trail(entity)
end

local function resolve_target(actor, dx, dy, tag, name, target)
	target = target or entities.get_with_tag(actor.x + dx, actor.y + dy, actor.z, tag)
	if not validate_interaction(actor, target, name) then
		return nil
	end
	if not utils.get_tag(target, tag) then
		event_log:add({ type = "action_failed", entity = target.name, reason = "Not " .. tag })
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
		if
			tar.default_action
			and (entity.can_perform and entity.can_perform[tar.default_action])
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
	assign_cost(entity, "place")
	event_log:add({ type = "entity_placed", entity = item.name, source = entity.name })
	return true
end

function actions:use_selected(entity, dx, dy)
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
		return self:use_item(entity, item, dx, dy)
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
	assign_cost(entity, "equip")
	event_log:add({ type = "item_equipped", entity = entity.name, item = item.name, slot = item.slot })
	return true
end

function actions:unequip_item(entity, item)
	inventory.unequip(entity, item.slot)
	assign_cost(entity, "unequip")
	event_log:add({ type = "item_unequipped", entity = entity.name, item = item.name, slot = item.slot })
	return true
end

function actions:use_item(entity, item, dx, dy)
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
	target = resolve_target(entity, dx, dy, "pickupable", "Pickup", target)
	if not target then
		return false
	end

	inventory.add(entity, target.item)

	entities.remove(target)
	assign_cost(entity, "pickup")
	event_log:add({ type = "entity_picked_up", entity = target.name, source = entity.name })
	return true
end

local function deal_damage(target, amount, src)
	local leftover = statuses.absorb(target, amount)
	if leftover > 0 then
		vitals.apply_damage(target, leftover, src)
	end
end

local function build_hit_sound(attacker, target, weapon)
	local ctx, cty = utils.get_center_of_footprint(target)
	local combat = attacker.combat
	return {
		x = target.x + ctx,
		y = target.y + cty,
		z = attacker.z,
		volume = (weapon and weapon.volume) or (combat and combat.attack_volume) or 6,
		reach = (weapon and weapon.reach) or (combat and combat.attack_reach) or 12,
		description = (weapon and weapon.sound) or (combat and combat.attack_sound) or "a thwack",
		source = attacker,
	}
end

local function emit_on_hit_effects(attacker, target, damage)
	local cx, cy = utils.get_center_of_footprint(attacker)
	local ctx, cty = utils.get_center_of_footprint(target)
	local acx, acy = attacker.x + cx, attacker.y + cy
	local tcx, tcy = target.x + ctx, target.y + cty

	local hit_burst = target.combat and target.combat.hit_burst --TODO: Hit burst and attack burst dup  a lot. Also should this go in vitals? So that statuses can also pop here...
	if hit_burst then
		particles:burst(
			tcx,
			tcy,
			target.z + 1,
			hit_burst,
			4, -- TODO: someday this and things like ths shake could be based on damage
			{ dir = { dx = tcx - acx, dy = tcy - acy }, spread = 1, smin = 3, smax = 10 }
		)
	end

	local attack_burst = attacker.combat and attacker.combat.attack_burst
	if attack_burst then
		particles:burst(
			tcx,
			tcy,
			target.z + 1,
			attack_burst,
			4,
			{ dir = { dx = tcx - acx, dy = tcy - acy }, spread = 1, smin = 3, smax = 10 }
		)
	end

	local damage_number = effects:add_from_template("damage_number", tcx, tcy, target.z)
	damage_number.glyph.char = tostring(math.floor(damage))
	animation.add_shake(target)
	animation.add_flash(target)
end
function actions:attack(entity, dx, dy, target_entity)
	local weapon = inventory.get_equipped(entity, "mainhand")
	target_entity = resolve_target(entity, dx, dy, "attackable", "Attack", target_entity)
	if not target_entity then
		return false
	end
	if entity.team ~= target_entity.team then
		assign_cost(entity, "attack")

		animation.add_bump(entity, target_entity.x, target_entity.y)
		local damage = stats.get(entity, "damage", "melee")
		deal_damage(target_entity, damage, entity.name)
		statuses.on_hit(entity, target_entity)

		emit_on_hit_effects(entity, target_entity, damage)
		sounds.emit(build_hit_sound(entity, target_entity, weapon))
	end
	return true
end

function actions:ranged_attack(entity, target_x, target_y, target_entity)
	local weapon = inventory.get_equipped(entity, "mainhand")
	if not weapon or not weapon.ranged then
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

	assign_cost(entity, "ranged_attack")
	inventory.use_charge(weapon)

	local damage = stats.get(entity, "damage", "ranged")
	deal_damage(target_entity, damage, entity.name)
	local shot_sound = build_hit_sound(entity, target_entity, weapon)
	shot_sound.defer_ring = true
	local player_heard = sounds.emit(shot_sound)

	local projectile = effects:add_from_template("projectile", entity.x, entity.y, entity.z)
	projectile.params.from = { x = entity.x, y = entity.y }
	projectile.params.to = target_entity
	projectile.params.duration = utils.distance_between(projectile.params.from, projectile.params.to)
		/ projectile.params.speed

	projectile.params.on_arrive = function()
		emit_on_hit_effects(entity, target_entity, damage) --TODO: someday I want statuses to trigger some of these, which would require thinking about this
		sounds.spawn_ring(build_hit_sound(entity, target_entity, weapon), player_heard)
	end

	statuses.on_hit(entity, target_entity) --TODO should on hit effects  apply from ranged attacks

	return true
end

function actions:interact(entity, dx, dy, target_entity)
	target_entity = resolve_target(entity, dx, dy, "interactable", "Interact", target_entity)
	if not target_entity then
		return false
	end

	if not statuses.can_be_interacted(target_entity) then
		event_log:add({ type = "action_failed", entity = target_entity.name, reason = "Interaction blocked" })
		return false
	end
	assign_cost(entity, "interact")
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
		event_log:add({ type = "action_failed", entity = entity.name, reason = "Actor tile not free" })
		return false
	end
	if not map:is_tile_free(target_dest_x, target_dest_y, target.z, skip) then
		event_log:add({ type = "action_failed", entity = target.name, reason = "Target tile not free" })
		return false
	end

	assign_cost(entity, "drag")
	record_trail(entity)
	entities.move_to(entity, actor_dest_x, actor_dest_y)
	entities.move_to(target, target_dest_x, target_dest_y)

	local dcx, dcy = utils.get_center_of_footprint(target)
	particles:burst(
		target_dest_x + dcx,
		target_dest_y + dcy,
		target.z + 1,
		"dust",
		2,
		{ spread = 4, smin = 1, smax = 3 }
	)

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
	assign_cost(entity, "wait")
	event_log:add({ type = "entity_waited", entity = entity.name, spam = true })
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
	elseif t == "equip_item" then
		return self:equip_item(entity, action.item)
	elseif t == "grab_interaction" then
		return self:drag(entity, action.dx, action.dy, action.target)
	elseif t == "use_selected" then
		return self:use_selected(entity, action.dx, action.dy)
	elseif t == "place_selected" then
		return self:place_selected(entity, action.dx, action.dy)
	elseif t == "wait" then
		return self:wait(entity)
	end

	return false
end

return actions
