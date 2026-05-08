local effect_types = require("visuals.effects.effect_types")
local utils = require("utils")

local effects = {
	effect_list = {},
	effect_type_dict = {},
}

function effects:get_effects(x, y, z)
	local ret = {}
	for _, effect in ipairs(self.effect_list) do
		if effect.x == x and effect.y == y and effect.z == z then
			table.insert(ret, effect)
		end
	end
	return ret
end

function effects:get_effect_list()
	return self.effect_list
end

function effects:add_effect(effect)
	table.insert(self.effect_list, effect)
end

function effects:add_from_template(name, x, y, z, overrides)
	local template = effect_types[name]
	if not template then
		error("Entity type '" .. tostring(name) .. "' does not exist")
	end
	local new_entity = utils.deep_copy(template)

	new_entity.x = x or 1
	new_entity.y = y or 1
	new_entity.z = z or 1

	if overrides then
		for k, v in pairs(overrides) do
			new_entity[k] = v
		end
	end

	self:add_effect(new_entity)
	return new_entity
end

local function update_effect_parts(parts, next_frame)
	local remaining = 0

	for i = #parts, 1, -1 do
		local part = parts[i]
		local max_frames = part.colors and #part.colors or 1
		if next_frame > max_frames then
			table.remove(parts, i)
		else
			remaining = remaining + 1
		end
	end

	return remaining
end

function effects:update(dt)
	for i = #self.effect_list, 1, -1 do
		local effect = self.effect_list[i]
		local params = effect.params
		params.lifespan = params.lifespan - dt

		if params.lifespan <= 0 then
			local i_next = params.i + 1
			local total_remaining = 0

			if effect.rects then
				total_remaining = total_remaining + update_effect_parts(effect.rects, i_next)
			end

			if total_remaining > 0 then
				params.i = i_next
				params.lifespan = params.initial_lifespan
			else
				table.remove(self.effect_list, i)
			end
		end
	end
end

return effects
