local entities = require("entities.entities")
local event_log = require("engine.event_log")
local stats = require("stats.stats")
local effects = require("visuals.effects.effects")
local utils = require("utils")
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
		if target.corpse then
			entities.add_from_template(target.corpse, target.x, target.y, target.z, { rotation = target.rotation })
		end
	end
end

function vitals.apply_heal(target, amount, source_name)
	if not target.stats or not target.stats.health then
		return nil
	end
	stats.change_current(target, "health", amount)

	local ctx, cty = utils.get_center_of_footprint(target)
	local tcx, tcy = target.x + ctx, target.y + cty
	local damage_number = effects:add_from_template(
		"damage_number",
		tcx,
		tcy,
		target.z,
		{ glyph = { char = 0, color = { 0.1, 0.8, 0.2, 0.5 }, size = 0.33 } }
	)
	damage_number.glyph.char = tostring(math.floor(amount))

	event_log:add({ type = "heal", entity = target.name, source = source_name, amount = amount })
end

return vitals
