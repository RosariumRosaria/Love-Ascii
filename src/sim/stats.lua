local event_log = require("src.engine.event_log")

local stats = {}

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
	return add, mul
end

return stats
