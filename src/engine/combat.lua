local utils = require("src.utils")
local stats = require("src.sim.stats")
local statuses = require("src.sim.statuses")
local inventory = require("src.sim.inventory")
local event_log = require("src.engine.event_log")
local vitals = require("src.engine.vitals")
local animation = require("src.visuals.render.animation")
local particles = require("src.visuals.particles.particles")
local combat_config = require("src.config.combat_config")
local map = require("src.map.map")
local render_config = require("src.config.render_config")
local combat = {}

local function spawn_burst(entity, type_name, count, opts)
	local cx, cy = utils.get_center_of_footprint(entity)
	particles:burst(entity.x + cx, entity.y + cy, entity.z, type_name, count, opts)
end

local default_volume = 6
local default_reach = 12
local default_description = "a thwack"
function combat.build_hit_sound(attacker, target, weapon, context)
	local ctx, cty = utils.get_center_of_footprint(target)
	weapon = weapon or stats.get_weapon(attacker, context)
	return {
		x = target.x + ctx,
		y = target.y + cty,
		z = attacker.z,
		volume = (weapon and weapon.volume) or default_volume,
		reach = (weapon and weapon.reach) or default_reach,
		description = (weapon and weapon.sound) or default_description,
		source = attacker,
	}
end

local function attack_values(attacker, context)
	local raw = stats.get(attacker, "damage", context) + stats.get(attacker, "strength", context)
	return raw, stats.get(attacker, "damage_spread", context)
end

local function band(value)
	return math.max(1, math.floor(value + 0.5))
end

function combat.damage_bands(attacker, context)
	local raw, spread = attack_values(attacker, context)
	return band(raw - spread), band(raw), band(raw + spread)
end

local function resolve(attacker, target, context)
	local raw, spread = attack_values(attacker, context)
	local outcome = {
		context = context,
		raw = raw,
	}

	local max_accuracy_mod = combat_config.max_accuracy_mod
	local solid = combat_config.solid
	local glance = combat_config.glance
	local accuracy = stats.get(attacker, "accuracy", context)
	local evasion = stats.get(target, "evasion", context)

	if not statuses.can_act(target) then
		evasion = 0
	end

	local dark_accuracy_mod = combat_config.dark_accuracy_mod
	if map.can_see(attacker, target.x, target.y) then
		dark_accuracy_mod = 0
	end
	local raw_diff = accuracy - evasion + dark_accuracy_mod

	local diff = max_accuracy_mod * math.tanh(raw_diff / max_accuracy_mod)
	local roll = math.floor(love.math.randomNormal(2, 5.5 + diff) + 0.5)
	roll = math.max(1, math.min(10, roll))

	outcome.quality = "hit"
	outcome.adjusted = outcome.raw

	if roll <= glance then
		outcome.quality = "glance"
		outcome.adjusted = outcome.adjusted - spread
	elseif roll >= solid then
		outcome.quality = "solid"
		outcome.adjusted = outcome.adjusted + spread
	end

	outcome.adjusted = band(outcome.adjusted)

	return outcome
end

function combat.strike(attacker, target, opts)
	local outcome = resolve(attacker, target, opts.context)
	local weapon = stats.get_weapon(attacker, opts.context)

	outcome.mitigation = {}

	local padding = stats.get(target, "padding", opts.context)
	local piercing = stats.get(attacker, "piercing", opts.context)
		+ (outcome.quality == "solid" and combat_config.solid_piercing or 0)
	local adjusted_padding = math.max(0, padding - piercing)
	outcome.amount = math.max(0, outcome.adjusted - adjusted_padding)

	local turned = outcome.adjusted - outcome.amount
	if turned > 0 then
		local worn = inventory.get_equipped(target, "armor")
		local noun = (worn and string.lower(worn.name or worn.key)) or target.padding_noun or "armor"
		outcome.mitigation[#outcome.mitigation + 1] = { amount = turned, verb = "turned", noun = noun }
	end

	outcome.amount = statuses.absorb(target, outcome.amount, outcome.mitigation)

	if outcome.amount > 0 then
		vitals.apply_damage(target, outcome.amount, attacker, true)
	end

	if outcome.quality ~= "glance" then
		statuses.on_hit(attacker, target, weapon)
	end

	if not opts.defer_feedback then
		combat.play_hit_feedback(attacker, target, outcome, weapon)
	end

	local weapon_name = weapon and weapon.name or "Unknown"
	event_log:add({
		type = "combat",
		entity = target,
		source = attacker,
		weapon = weapon_name,
		quality = outcome.quality,
		mitigation = outcome.mitigation,
		amount = outcome.amount,
		x = target.x,
		y = target.y,
	})

	return outcome
end

function combat.play_hit_feedback(attacker, target, outcome, weapon)
	weapon = weapon or stats.get_weapon(attacker, outcome.context)
	local cx, cy = utils.get_center_of_footprint(attacker)
	local ctx, cty = utils.get_center_of_footprint(target)
	local acx, acy = attacker.x + cx, attacker.y + cy
	local tcx, tcy = target.x + ctx, target.y + cty

	local hit_burst = target.combat and target.combat.hit_burst
	local burst_count = render_config.combat.burst_count
	if hit_burst then
		spawn_burst(
			target,
			hit_burst,
			burst_count,
			{ -- TODO: someday this and things like ths shake could be based on damage
				dir = { dx = tcx - acx, dy = tcy - acy },
				spread = 1,
				smin = 4,
				smax = 10,
			}
		)
	end

	local attack_burst = weapon and weapon.attack_burst
	if attack_burst then
		spawn_burst(target, attack_burst, burst_count, {
			dir = { dx = tcx - acx, dy = tcy - acy },
			spread = 1,
			smin = 4,
			smax = 10,
		})
	end

	animation.add_shake(target)
	animation.add_flash(target)

	if outcome.amount > 0 then
		local opts = {}
		if outcome.quality == "glance" then
			opts.color = render_config.combat.glance_damage_color
		end
		if outcome.quality == "solid" then
			opts.color = render_config.combat.solid_damage_color
		end

		vitals.spawn_damage_numbers(target, outcome.amount, opts)
	end
end

return combat
