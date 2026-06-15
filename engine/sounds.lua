local entities = require("entities.entities")
local utils = require("utils")
local sounds = {}

function sounds.audible(entity, sound)
	return utils.distance_between(entity, sound) <= sound.intensity
end

local function candidates(s)
	local candidate_list = {}

	for dy = -s.intensity, s.intensity do
		for dx = -s.intensity, s.intensity do
			local tx, ty = s.x + dx, s.y + dy
			local entity_list = entities.get_list_at_column(tx, ty)
			for _, e in ipairs(entity_list) do
				table.insert(candidate_list, e)
			end
		end
	end

	return candidate_list
end

function sounds.emit(x, y, z, intensity, description, source)
	local s = { x = x, y = y, z = z, description = description, intensity = intensity, source = source }

	for _, entity in ipairs(candidates(s)) do
		if s.source ~= entity then
			if sounds.audible(entity, s) then
				entities.hear(entity, s)
			end
		end
	end
end

return sounds
