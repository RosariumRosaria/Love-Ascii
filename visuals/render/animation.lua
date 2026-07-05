local game_cfg = require("config.game_config")
local render_cfg = require("config.render_config")
local entities = require("entities.entities")
local effects = require("visuals.effects.effects")
local animation_types = require("visuals.render.animation_types")
local utils = require("utils")

local animation = {}
local base_duration = (game_cfg.timing.turn_delay + render_cfg.animation.tween_slack) * render_cfg.animation.tween_time
local min_step_fraction = 0.25

function animation.add_from_template(name, overrides)
	local new_anim = utils.create_instance_from_template(animation_types, name, overrides)
	new_anim.elapsed = 0
	return new_anim
end

local function trailing_edge_offsets(offsets, dx, dy)
	if dx == 0 and dy == 0 then
		return offsets
	end
	local sx, sy = utils.sign(dx), utils.sign(dy)
	local back_x, back_y
	for _, c in ipairs(offsets) do
		if sx ~= 0 and (not back_x or c.dx * sx < back_x) then
			back_x = c.dx * sx
		end
		if sy ~= 0 and (not back_y or c.dy * sy < back_y) then
			back_y = c.dy * sy
		end
	end

	local ret = {}
	for _, c in ipairs(offsets) do
		if (sx ~= 0 and c.dx * sx == back_x) or (sy ~= 0 and c.dy * sy == back_y) then
			ret[#ret + 1] = c
		end
	end
	return ret
end

local function anim(entity)
	local a = entity.anim
	if not a then
		a = {}
		entity.anim = a
	end
	return a
end

function animation.spawn_pending_trail(entity)
	local a = entity.anim
	local pt = a and a.pending_trail
	if not pt then
		return
	end
	local offsets = trailing_edge_offsets(utils.footprint_offsets(entity), entity.x - pt.x, entity.y - pt.y)
	for _, c in ipairs(offsets) do
		local effect = effects:add_from_template("trail", pt.x + c.dx, pt.y + c.dy, pt.z)
		if pt.color then
			effect.rects[1].colors[1] = pt.color
		end
	end
	a.pending_trail = nil
end

function animation.set_pending_trail(entity)
	anim(entity).pending_trail = { x = entity.x, y = entity.y, z = entity.z, color = entity.appearance.effect_color }
end

function animation.add_bump(entity, target_x, target_y)
	if not entity then
		return false
	end
	local bump = animation.add_from_template("bump")

	bump.dx = utils.sign(target_x - entity.x) * bump.amount
	bump.dy = utils.sign(target_y - entity.y) * bump.amount

	anim(entity).bump = bump
end

function animation.add_flash(entity)
	if not entity then
		return false
	end
	local flash = animation.add_from_template("flash")

	anim(entity).flash = flash
end

function animation.add_shake(entity)
	if not entity then
		return false
	end
	local shake = animation.add_from_template("shake")

	anim(entity).shake = shake
end

local function ensure_init(entity)
	local a = anim(entity)
	if not a.tween_x or not a.tween_y then
		a.tween_x = entity.x
		a.tween_y = entity.y
		a.tween_from_x = entity.x
		a.tween_from_y = entity.y
		a.tween_target_x = entity.x
		a.tween_target_y = entity.y
		a.tween_elapsed = base_duration
		a.tween_duration = base_duration
	end
end

local function start_tween_to(entity, target)
	local a = entity.anim
	a.tween_from_x = a.tween_x
	a.tween_from_y = a.tween_y
	a.tween_target_x = target.x
	a.tween_target_y = target.y
	a.tween_elapsed = 0
	a.tween_duration = math.max(min_step_fraction * base_duration, base_duration / (#a.move_queue + 1))
end

local function advance_and_write(entity, dt)
	local a = entity.anim
	a.tween_elapsed = math.min(a.tween_elapsed + dt, a.tween_duration)
	local t = a.tween_elapsed / a.tween_duration
	a.tween_x = utils.lerp(a.tween_from_x, a.tween_target_x, t)
	a.tween_y = utils.lerp(a.tween_from_y, a.tween_target_y, t)

	a.render_x = a.tween_x
	a.render_y = a.tween_y
end

function animation.update(dt)
	for _, entity in ipairs(entities.get_list()) do
		ensure_init(entity)
		local a = entity.anim
		local move_queue_length = a.move_queue and #a.move_queue or 0

		if a.tween_elapsed >= a.tween_duration and move_queue_length > 0 then
			start_tween_to(entity, table.remove(a.move_queue, 1))
		end
		advance_and_write(entity, dt)

		if a.pending_trail and a.tween_elapsed >= 0.8 * a.tween_duration then
			animation.spawn_pending_trail(entity)
		end

		for key, aa in pairs(a) do
			if type(aa) == "table" and aa.elapsed then --TODO brittle. move elapsed anims to subtable
				aa.elapsed = aa.elapsed + dt
				if aa.elapsed >= aa.duration then
					a[key] = nil
				end
			end
		end

		if a.bump then -- TODO, someday anims should be more generic
			local p = a.bump.elapsed / a.bump.duration
			local curve = math.sin(p * math.pi)
			a.render_x = a.render_x + a.bump.dx * curve
			a.render_y = a.render_y + a.bump.dy * curve
		end

		if a.shake then
			local p = a.shake.elapsed / a.shake.duration
			a.render_x = a.render_x + (utils.randomize_sign() * a.shake.amount * (1 - p))
			a.render_y = a.render_y + (utils.randomize_sign() * a.shake.amount * (1 - p))
		end
	end
end

return animation
