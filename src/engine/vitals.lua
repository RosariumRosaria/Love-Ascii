local entities = require("entities.entities")
local event_log = require("engine.event_log")
local stats = require("stats.stats")
local effects = require("visuals.effects.effects")
local utils = require("utils")
local render_utils = require("visuals.render.utils")
local vitals = {}

function vitals.spawn_damage_numbers(target, amount, opts)
	local ctx, cty = utils.get_center_of_footprint(target)
	local tcx, tcy = target.x + ctx, target.y + cty

	local damage_number = effects:add_from_template("damage_number", tcx, tcy, target.z)
	damage_number.glyph.char = tostring(math.floor(amount))
	if opts then
		damage_number.glyph.color = opts.color or damage_number.glyph.color
		damage_number.glyph.size = opts.size or damage_number.glyph.size
	end
	return damage_number
end

function vitals.apply_damage(target, amount, source_name, delay)
	if not target.stats or not target.stats.health then
		return nil
	end

	stats.change_current(target, "health", -amount)
	local after = stats.get_current(target, "health")
	event_log:add({ type = "damage", entity = target.name, source = source_name, amount = amount })
	if not delay then
		vitals.spawn_damage_numbers(target, amount)
	end
	local killed = after <= 0

	if killed then
		target.dead = true
		event_log:add({ type = "entity_died", entity = target.name, source = source_name })
		entities.remove(target)
		if target.type == "actor" or target.corpse then
			local overrides = {
				rotation = target.rotation,
			}

			if not target.corpse and target.appearance then
				local color = {}
				for i, c in ipairs(target.appearance.color) do
					local desaturated = render_utils.desaturate(c, 0.5)
					desaturated[4] = 0.5
					color[i] = desaturated
				end

				overrides.footprint = target.footprint and utils.deep_copy(target.footprint)
				overrides.render_layer = "ground"
				overrides.natural_rotation = target.natural_rotation
				overrides.appearance = {
					chars = utils.deep_copy(target.appearance.chars),
					color = color,
				}
			end

			local corpse =
				entities.add_from_template(target.corpse or "corpse", target.x, target.y, target.z, overrides)

			if target.inventory then
				corpse.inventory = target.inventory
			end
		end
	end
end

function vitals.apply_heal(target, amount, source_name, delay)
	if not target.stats or not target.stats.health then
		return nil
	end
	stats.change_current(target, "health", amount)
	if not delay then
		vitals.spawn_damage_numbers(target, amount, { color = { 0.1, 0.8, 0.2, 0.5 } })
	end
	event_log:add({ type = "heal", entity = target.name, source = source_name, amount = amount })
end

return vitals
