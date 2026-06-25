local entities = require("entities.entities")
local event_log = require("engine.event_log")
local stats = require("stats.stats")

local vitals = {}

function vitals.apply_damage(target, amount, source_name)
	if not target.stats or not target.stats.health then
		return nil
	end

	stats.change_current(target, "health", -amount)
	local after = stats.get_current(target, "health")
	event_log:add({ type = "damage", entity = target.name, source = source_name, amount = amount })

	local killed = after <= 0

	if killed then
		target.dead = true
		event_log:add({ type = "entity_died", entity = target.name, source = source_name })
		entities.remove(target)
	end
end

function vitals.apply_heal(target, amount, source_name)
	if not target.stats or not target.stats.health then
		return nil
	end
	stats.change_current(target, "health", amount)

	event_log:add({ type = "heal", entity = target.name, source = source_name, amount = amount })
end

return vitals
