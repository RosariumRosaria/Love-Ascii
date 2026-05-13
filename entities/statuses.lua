local status_types = require("entities.status_types")
local utils = require("utils")
local statuses = {}

function statuses.add_status(entity, name, overrides)
	local template = status_types[name]
	if not template then
		error("Status '" .. tostring(name) .. "' does not exist")
	end

	local new_status = utils.deep_copy(template)

	if overrides then
		for k, v in pairs(overrides) do
			new_status[k] = v
		end
	end

	if not entity.statuses then
		entity.statuses = {}
	end

	table.insert(entity.statuses, new_status)
end

function statuses.get_modifier_sum(entity, stat_name)
	local add, mul = 0, 1
	if not entity.statuses then
		return add, mul
	end
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
	return add, mul
end

function statuses.tick_entity(entity)
	if not entity.statuses then
		return
	end

	for i = #entity.statuses, 1, -1 do
		local status = entity.statuses[i]
		if status.on_tick then
			status.on_tick(entity)
		end

		status.duration = status.duration - 1
		if status.duration <= 0 then
			table.remove(entity.statuses, i)
		end

		if entity.dead then
			break
		end
	end
end

return statuses
