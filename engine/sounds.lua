local entities = require("entities.entities")
local utils = require("utils")
local effects = require("visuals.effects.effects")
local sounds = {}

function sounds.perceived(entity, sound)
	local d = utils.distance_between(entity, sound)
	if d >= sound.reach then
		return nil
	end
	return sound.volume * (1 - d / sound.reach)
end

local function candidates(s)
	local candidate_list = {}

	for dy = -s.reach, s.reach do
		for dx = -s.reach, s.reach do
			local tx, ty = s.x + dx, s.y + dy
			local entity_list = entities.get_list_at_column(tx, ty)
			for _, e in ipairs(entity_list) do
				table.insert(candidate_list, e)
			end
		end
	end

	return candidate_list
end

local BLOOM_MIN_VOLUME = 5
function sounds.emit(s)
	if not (s.source and s.source.sound_ring and not s.source.sound_ring.dead) then
		if s.volume > BLOOM_MIN_VOLUME then
			local ring = effects:add_from_template("sound_flood", s.x, s.y, s.z)
			ring.params.reach = s.reach
			s.source.sound_ring = ring
		end
	end
	for _, entity in ipairs(candidates(s)) do
		if s.source ~= entity then
			local perceived = sounds.perceived(entity, s)
			if perceived then
				entities.hear(entity, s, perceived)
			end
		end
	end
end

return sounds
