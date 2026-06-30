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

	local ox, oy = math.floor(s.x), math.floor(s.y)
	for dy = -s.reach, s.reach do
		for dx = -s.reach, s.reach do
			local tx, ty = ox + dx, oy + dy
			local entity_list = entities.get_list_at_column(tx, ty)
			for _, e in ipairs(entity_list) do
				table.insert(candidate_list, e)
			end
		end
	end

	return candidate_list
end

local RING_MIN_VOLUME = 5

function sounds.emit(s)
	local player_heard = false
	local candidate_list = candidates(s)
	for _, entity in ipairs(candidate_list) do
		local perceived = sounds.perceived(entity, s)
		if s.source ~= entity then
			if perceived then
				entities.hear(entity, s, perceived)
			end
		end

		if entities.is_player(entity) and perceived then
			player_heard = true
		end
	end

	if player_heard and not (s.source and s.source.sound_ring and not s.source.sound_ring.dead) then
		if s.volume > RING_MIN_VOLUME then
			local ring = effects:add_from_template("sound_ring", math.floor(s.x), math.floor(s.y), s.z)
			ring.params.reach = s.reach
			if s.source then
				s.source.sound_ring = ring
			end
		end
	end
end

return sounds
