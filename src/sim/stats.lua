local event_log = require("src.engine.event_log")
local item_types = require("src.sim.item_types")

local stats = {}

local function covers_context(weapon, context)
	if not weapon then
		return false
	end
	if context == "melee" and weapon.ranged then
		return false
	end
	return true
end

function stats.get_weapon(entity, context)
	if not entity then
		return nil
	end
	local equipped = entity.inventory and entity.inventory.equipped and entity.inventory.equipped.mainhand
	if covers_context(equipped, context) then
		return equipped
	end
	return entity.natural_weapon and item_types[entity.natural_weapon] or nil
end

local function applies_in(mod, context)
	return mod.context == nil or mod.context == context
end

local function apply_mod(mod, add, mul)
	if mod.op == "add" then
		return add + mod.value, mul
	elseif mod.op == "mul" then
		return add, mul * mod.value
	end
	return add, mul
end

function stats.get(entity, name, context)
	local stat = entity.stats and entity.stats[name]
	if not stat then
		return 0
	end
	local add, mul = stats.sum_modifiers(entity, name, context)
	return (stat.base + add) * mul
end

function stats.get_current(entity, name)
	local stat = entity.stats and entity.stats[name]
	if not stat then
		return 0
	end
	if stat.current == nil then
		return stats.get(entity, name)
	end
	return stat.current
end

function stats.set_current(entity, name, value)
	local stat = entity.stats and entity.stats[name]
	if not stat or stat.current == nil then
		return
	end
	local max = stats.get(entity, name)
	if value < 0 then
		value = 0
	elseif value > max then
		value = max
	end
	stat.current = value
end

function stats.change_current(entity, name, value)
	local stat = entity.stats and entity.stats[name]
	if not stat or stat.current == nil then
		return
	end
	local new = stat.current + value
	stats.set_current(entity, name, new)
end

function stats.sum_modifiers(entity, stat_name, context)
	local add, mul = 0, 1

	if entity.statuses then
		for _, status in ipairs(entity.statuses) do
			if status.modifiers then
				for _, mod in ipairs(status.modifiers) do
					if mod.stat == stat_name and applies_in(mod, context) then
						add, mul = apply_mod(mod, add, mul)
					end
				end
			end
		end
	end

	if entity.inventory and entity.inventory.equipped then
		for _, item in pairs(entity.inventory.equipped) do
			if item.modifiers then
				for _, mod in ipairs(item.modifiers) do
					if mod.stat == stat_name and applies_in(mod, context) then
						add, mul = apply_mod(mod, add, mul)
					end
				end
			end
		end
	end

	local mainhand = entity.inventory and entity.inventory.equipped and entity.inventory.equipped.mainhand
	local natural = not covers_context(mainhand, context)
		and entity.natural_weapon
		and item_types[entity.natural_weapon]
	if natural and natural.modifiers then
		for _, mod in ipairs(natural.modifiers) do
			if mod.stat == stat_name and applies_in(mod, context) then
				add, mul = apply_mod(mod, add, mul)
			end
		end
	end

	return add, mul
end

return stats
