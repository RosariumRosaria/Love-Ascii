local utils = require("src.utils")
local entities = require("src.sim.entities")
local event_text = {}

local function refer(ev, field)
	local name = ev[field]
	if not name then
		return nil
	end
	if not ev[field .. "_kind"] then
		return string.lower(name), false
	end

	local id = ev[field .. "_id"]
	if id then
		local player = entities.player
		if player and player.id == id then
			return "you", true
		end
		local live = entities.get_by_id(id)
		if live then
			name = live.name
		end
	end
	return "a " .. string.lower(name), false
end

local function refer_capital(ev, field)
	local text, is_player = refer(ev, field)
	return text and utils.capitalize(text), is_player
end

local function was(is_player)
	return is_player and "were" or "was"
end

function event_text.describe(ev)
	local subject, subject_is_player = refer_capital(ev, "entity")

	if ev.type == "combat" then
		local quality = ""
		if ev.quality == "glance" then
			quality = "glancing "
		end
		if ev.quality == "solid" then
			quality = "solid "
		end

		local line = refer_capital(ev, "source") .. " landed a " .. quality .. "blow on " .. refer(ev, "entity") .. "."

		local tally = {}
		if ev.amount > 0 then
			tally[#tally + 1] = ev.amount .. " damage"
		end
		if ev.absorbed and ev.absorbed > 0 then
			tally[#tally + 1] = ev.absorbed .. " absorbed by their " .. ev.absorbed_by
		end
		if #tally > 0 then
			line = line .. " (" .. table.concat(tally, ", ") .. ")"
		end
		return line
	elseif ev.type == "damage" then
		return subject .. " took damage from " .. refer(ev, "source") .. ". (" .. ev.amount .. " damage)"
	elseif ev.type == "heal" then
		return subject .. " recovered from " .. refer(ev, "source") .. ". (" .. ev.amount .. " healed)"
	elseif ev.type == "status_applied" then
		if ev.source then
			return refer_capital(ev, "source")
				.. " inflicted "
				.. string.lower(ev.status)
				.. " on "
				.. refer(ev, "entity")
				.. "."
		end
		return utils.capitalize(string.lower(ev.status)) .. " took hold of " .. refer(ev, "entity") .. "."
	elseif ev.type == "status_expired" then
		return utils.capitalize(string.lower(ev.status)) .. " wore off " .. refer(ev, "entity") .. "."
	elseif ev.type == "entity_died" then
		return subject .. " " .. was(subject_is_player) .. " killed by " .. refer(ev, "source") .. "."
	elseif ev.type == "entity_dragged" then
		return refer_capital(ev, "source")
			.. " dragged "
			.. refer(ev, "entity")
			.. " to "
			.. ev.dest_x
			.. ", "
			.. ev.dest_y
			.. "."
	elseif ev.type == "entity_picked_up" then
		return refer_capital(ev, "source") .. " picked up " .. refer(ev, "entity") .. "."
	elseif ev.type == "entity_placed" then
		return refer_capital(ev, "source") .. " placed " .. refer(ev, "entity") .. "."
	elseif ev.type == "item_equipped" then
		return subject .. " equipped " .. refer(ev, "item") .. ". (" .. ev.slot .. ")"
	elseif ev.type == "item_unequipped" then
		return subject .. " unequipped " .. refer(ev, "item") .. ". (" .. ev.slot .. ")"
	elseif ev.type == "item_used" then
		return subject .. " used " .. refer(ev, "item") .. "."
	elseif ev.type == "item_consumed" then
		return refer_capital(ev, "item") .. " was used up."
	elseif ev.type == "entity_waited" then
		return subject .. " waited."
	elseif ev.type == "describe" then
		return subject .. ": " .. ev.description
	elseif ev.type == "action_failed" then
		return subject .. " could not: " .. string.lower(ev.reason) .. "."
	elseif ev.type == "sound" then
		return "You heard " .. ev.description .. "."
	elseif ev.type == "debug" then
		return "[DEBUG] " .. ev.message
	end
end

return event_text
