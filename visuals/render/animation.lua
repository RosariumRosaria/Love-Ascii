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

function animation.spawn_pending_trail(entity)
	local pt = entity.pending_trail
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
	entity.pending_trail = nil
end

function animation.add_bump(entity, target_x, target_y)
	if not entity then
		return false
	end
	local bump = animation.add_from_template("bump")

	bump.dx = utils.sign(target_x - entity.x) * bump.amount
	bump.dy = utils.sign(target_y - entity.y) * bump.amount

	entity.bump = bump
end

local function ensure_init(entity)
	if not entity.tween_x or not entity.tween_y then
		entity.tween_x = entity.x
		entity.tween_y = entity.y
		entity.tween_from_x = entity.x
		entity.tween_from_y = entity.y
		entity.tween_target_x = entity.x
		entity.tween_target_y = entity.y
		entity.tween_elapsed = base_duration
		entity.tween_duration = base_duration
	end
end

local function start_tween_to(entity, target)
	entity.tween_from_x = entity.tween_x
	entity.tween_from_y = entity.tween_y
	entity.tween_target_x = target.x
	entity.tween_target_y = target.y
	entity.tween_elapsed = 0
	entity.tween_duration = math.max(min_step_fraction * base_duration, base_duration / (#entity.move_queue + 1))
end

local function advance_and_write(entity, dt)
	entity.tween_elapsed = math.min(entity.tween_elapsed + dt, entity.tween_duration)
	local t = entity.tween_elapsed / entity.tween_duration
	entity.tween_x = entity.tween_from_x + (entity.tween_target_x - entity.tween_from_x) * t
	entity.tween_y = entity.tween_from_y + (entity.tween_target_y - entity.tween_from_y) * t

	entity.render_x = entity.tween_x
	entity.render_y = entity.tween_y
end

function animation.update(dt)
	for _, entity in ipairs(entities.get_list()) do
		ensure_init(entity)
		local move_queue_length = entity.move_queue and #entity.move_queue or 0

		if entity.tween_elapsed >= entity.tween_duration and move_queue_length > 0 then
			start_tween_to(entity, table.remove(entity.move_queue, 1))
		end
		advance_and_write(entity, dt)

		if entity.pending_trail and entity.tween_elapsed >= 0.8 * entity.tween_duration then
			animation.spawn_pending_trail(entity)
		end

		if entity.bump then
			entity.bump.elapsed = entity.bump.elapsed + dt
			if entity.bump.elapsed >= entity.bump.duration then
				entity.bump = nil
			else
				local p = entity.bump.elapsed / entity.bump.duration
				local curve = math.sin(p * math.pi)
				entity.render_x = entity.render_x + entity.bump.dx * curve
				entity.render_y = entity.render_y + entity.bump.dy * curve
			end
		end
	end
end

return animation
