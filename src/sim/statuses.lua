local status_types = require("src.sim.status_types")
local utils = require("src.utils")
local event_log = require("src.engine.event_log")
local vitals = require("src.engine.vitals")
local statuses = {}

function statuses.find(entity, key)
	if not entity.statuses then
		return nil
	end
	for _, status in ipairs(entity.statuses) do
		if status.key == key then
			return status
		end
	end
	return nil
end

function statuses.absorb_pool(target)
	if not target.statuses then
		return 0
	end
	local total = 0
	for _, status in ipairs(target.statuses) do
		if utils.get_tag(status, "absorbs") then
			total = total + (status.hp or 0)
		end
	end
	return total
end

function statuses.absorb(target, amount)
	local absorbers = statuses.with_tag(target, "absorbs")
	local absorbed_by
	for _, absorber in ipairs(absorbers) do
		local soaked = math.min(amount, absorber.hp)
		absorber.hp = absorber.hp - soaked
		amount = amount - soaked
		if soaked > 0 then
			absorbed_by = absorbed_by or absorber.absorb_noun or string.lower(absorber.name or absorber.key)
		end
		if absorber.hp == 0 and utils.get_tag(absorber, "remove_when_empty") then
			statuses.remove(target, absorber.key)
		end
	end
	return amount, absorbed_by
end

function statuses.remove_with_tag(entity, tag)
	local status_list = statuses.with_tag(entity, tag)
	if status_list and #status_list > 0 then
		statuses.remove(entity, status_list[1].key)
	end
end

function statuses.remove(entity, key)
	if not entity.statuses then
		return
	end
	for i, status in ipairs(entity.statuses) do
		if status.key == key then
			table.remove(entity.statuses, i)
			event_log:add({
				type = "status_expired",
				entity = entity,
				status = status.name,
				silent = status.silent,
				x = entity.x,
				y = entity.y,
			})
			return
		end
	end
end

function statuses.has_tag(entity, tag)
	return utils.any_with_tag(entity.statuses, tag)
end

function statuses.with_tag(entity, tag)
	return utils.with_tag(entity.statuses, tag)
end

function statuses.add_from_template(entity, name, overrides, source)
	local new_status = utils.create_instance_from_template(status_types, name, overrides)
	if entity.type ~= "actor" and not utils.get_tag(new_status, "applies_to_props") then
		return --TODO someday this should be better, like gating depending on status type.
	end

	if not entity.statuses then
		entity.statuses = {}
	end

	local existing_status = statuses.find(entity, new_status.key)

	if existing_status then
		-- [[TODO Could maybe be more robust, like checking if the damage is higher instead of just refreshing the duration
		-- Or should it care about the source? Maybe only refresh if it's the same source? Also I feel like statuses should be able to call out if they stack or not]]
		if existing_status.duration and new_status.duration then
			existing_status.duration = math.max(existing_status.duration, new_status.duration)
		end
		return
	end
	event_log:add({
		type = "status_applied",
		entity = entity,
		status = new_status.name,
		source = source,
		silent = new_status.silent,
		x = entity.x,
		y = entity.y,
	})
	table.insert(entity.statuses, new_status)
end

local function tick(entity, status)
	if status.on_tick then
		if utils.chance(status.on_tick.chance or 100) then
			if status.on_tick.damage then
				vitals.apply_damage(entity, status.on_tick.damage, status.name)
			end
			if status.on_tick.heal then
				vitals.apply_heal(entity, status.on_tick.heal, status.name)
			end
		end
	end

	if status.duration then
		status.duration = status.duration - 1
		if status.duration <= 0 then
			statuses.remove(entity, status.key)
		end
	end
end

function statuses.tick_entity(entity)
	if not entity.statuses then
		return
	end

	for i = #entity.statuses, 1, -1 do
		tick(entity, entity.statuses[i])

		if entity.dead then
			break
		end
	end
end

function statuses.can_act(entity)
	return not statuses.has_tag(entity, "disables_action")
end

function statuses.can_be_interacted(entity)
	return not statuses.has_tag(entity, "disables_interaction")
end

local function apply_from_source(entity, source)
	local spec = source.applies_status
	if not spec then
		return
	end
	local overrides = spec.silent and { silent = true } or nil
	for _, status in ipairs(spec) do
		statuses.add_from_template(entity, status, overrides, source)
	end
end

function statuses.apply_from_tile(entity, tile_stack)
	if not tile_stack then
		return
	end
	for _, tile in ipairs(tile_stack) do
		apply_from_source(entity, tile)
	end
end

function statuses.apply_from_entities(entity, entity_list)
	for i = 1, #entity_list do
		local source = entity_list[i]
		if source ~= entity and not source.dead then
			apply_from_source(entity, source)
		end
	end
end

function statuses.on_hit(attacker, target, weapon)
	if not (weapon and weapon.applies_on_hit) then
		return
	end
	for _, status in ipairs(weapon.applies_on_hit) do
		if utils.chance(status.chance or 100) then
			statuses.add_from_template(target, status.name, nil, attacker)
		end
	end
end

return statuses
