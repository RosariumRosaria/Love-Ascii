local visual_types = require("visuals/visual_types")

local visuals = {
	visual_list = {},
	visual_type_dict = {},
}

function visuals:get_visuals(x, y, z)
	local ret = {}
	for _, visual in ipairs(self.visual_list) do
		if visual.x == x and visual.y == y and visual.z == z then
			table.insert(ret, visual)
		end
	end
	return ret
end

function visuals:get_visual_list()
	return self.visual_list
end

function visuals:add_visual(visual)
	table.insert(self.visual_list, visual)
end

local function deep_copy(tbl)
	local copy = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			copy[k] = deep_copy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function visuals:add_from_template(name, x, y, z, overrides)
	local template = visual_types[name]
	if not template then
		error("Entity type '" .. tostring(name) .. "' does not exist")
	end
	local new_entity = deep_copy(template)

	new_entity.x = x or 1
	new_entity.y = y or 1
	new_entity.z = z or 1

	if overrides then
		for k, v in pairs(overrides) do
			new_entity[k] = v
		end
	end

	self:add_visual(new_entity)
	return new_entity
end

local function update_visual_parts(parts, next_frame)
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

function visuals:update(dt)
	for i = #self.visual_list, 1, -1 do
		local visual = self.visual_list[i]
		local params = visual.params
		params.lifespan = params.lifespan - dt

		if params.lifespan <= 0 then
			local i_next = params.i + 1
			local total_remaining = 0

			if visual.rects then
				total_remaining = total_remaining + update_visual_parts(visual.rects, i_next)
			end

			if total_remaining > 0 then
				params.i = i_next
				params.lifespan = params.initial_lifespan
			else
				table.remove(self.visual_list, i)
			end
		end
	end
end

return visuals
