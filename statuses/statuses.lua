local status_types = require("statuses.status_types")
local utils = require("utils")
local event_log = require("engine.event_log")
local vitals = require("engine.vitals")
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

function statuses.absorb(target, amount)
	local absorbers = statuses.with_tag(target, "absorbs")
	for _, absorber in ipairs(absorbers) do
		local soaked = math.min(amount, absorber.hp)
		absorber.hp = absorber.hp - soaked
		amount = amount - soaked
		if absorber.hp == 0 and utils.get_tag(absorber, "remove_when_empty") then
			statuses.remove(target, absorber.key)
		end
	end
	return amount
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
				entity = entity.name,
				status = status.name,
				silent = status.silent,
			})
			return
		end
	end
end

function statuses.has_tag(entity, tag)
	return utils.has_tag(entity.statuses, tag)
end

function statuses.with_tag(entity, tag)
	return utils.with_tag(entity.statuses, tag)
end

function statuses.add_from_template(entity, name, overrides, source)
	local new_status = utils.create_instance_from_template(status_types, name, overrides)

	new_status.source = source or { name = "Unknown" }

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
		entity = entity.name,
		status = new_status.name,
		source = new_status.source.name,
		silent = new_status.silent,
	})
	table.insert(entity.statuses, new_status)
end

local function tick(entity, status)
	if status.on_tick then
		if status.on_tick.damage then
			vitals.apply_damage(entity, status.on_tick.damage, status.name)
		end
		if status.on_tick.heal then
			vitals.apply_heal(entity, status.on_tick.heal, status.name)
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

function statuses.get_visual_state(entity) --TODO, EXTEND TO CHAR REPLACE
	local alpha = 1
	local tint = { 1, 1, 1 }
	if not entity.statuses then
		return { alpha = alpha, tint = tint }
	end
	for _, status in ipairs(entity.statuses) do
		local v = status.visual
		if v then
			if v.alpha then
				alpha = alpha * v.alpha
			end
			if v.tint then
				tint[1] = tint[1] * (v.tint[1] or 1)
				tint[2] = tint[2] * (v.tint[2] or 1)
				tint[3] = tint[3] * (v.tint[3] or 1)
			end
		end
	end
	return { alpha = alpha, tint = tint }
end

function statuses.apply_from_tile(entity, tile_stack)
	if not tile_stack then
		return
	end
	for _, tile in ipairs(tile_stack) do
		if tile.applies_status then
			local overrides = tile.applies_status.silent and { silent = true } or nil
			for _, status in ipairs(tile.applies_status) do
				statuses.add_from_template(entity, status, overrides, tile)
			end
		end
	end
end

function statuses.on_hit(attacker, target)
	if not attacker.applies_on_hit then
		return
	end
	for _, status in ipairs(attacker.applies_on_hit) do
		if utils.chance(status.chance or 100) then
			statuses.add_from_template(target, status.name, nil, attacker)
		end
	end
end

return statuses
