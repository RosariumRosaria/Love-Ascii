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

function effects:remove_effect(effect)
	utils.remove_from_list(self.effect_list, effect)
end
function effects:add_from_template(name, x, y, z, overrides)
	local new_effect = utils.create_instance_from_template(effect_types, name, overrides)
	new_effect.x = x or 1
	new_effect.y = y or 1
	new_effect.z = z or 1
	self:add_effect(new_effect)
	return new_effect
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
			if params.repeats then
				local cycle = params.frames or 1
				params.i = (params.i % cycle) + 1
				params.lifespan = params.initial_lifespan
			else
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
end

return effects
