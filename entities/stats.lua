local event_log = require("engine.event_log")

local stats = {}

function stats.get_stat(entity, name, context)
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
		return stats.get_stat(entity, name)
	end
	return stat.current
end

function stats.set_current(entity, name, value)
	local stat = entity.stats and entity.stats[name]
	if not stat or stat.current == nil then
		return
	end
	local max = stats.get_stat(entity, name)
	if value < 0 then
		value = 0
	elseif value > max then
		value = max
	end
	stat.current = value
end

function stats.sum_modifiers(entity, stat_name, context)
	local add, mul = 0, 1

	if entity.statuses then
		for _, status in ipairs(entity.statuses) do
			if status.modifiers then
				for _, mod in ipairs(status.modifiers) do
					if mod.stat == stat_name then
						if mod.op == "add" then
							add = add + mod.value
						elseif mod.op == "mul" then
							mul = mul * mod.value
						end
					end
				end
			end
		end
	end

	if entity.inventory and entity.inventory.equipped then
		for _, item in pairs(entity.inventory.equipped) do
			local skip = context == "melee" and item.ranged
			if not skip and item.modifiers then
				for _, mod in ipairs(item.modifiers) do
					if mod.stat == stat_name then
						if mod.op == "add" then
							add = add + mod.value
						elseif mod.op == "mul" then
							mul = mul * mod.value
						end
					end
				end
			end
		end
	end
	return add, mul
end

return stats
