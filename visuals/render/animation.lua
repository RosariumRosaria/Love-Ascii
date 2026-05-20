local game_cfg = require("config.game_config")
local render_cfg = require("config.render_config")
local entities = require("entities.entities")
local effects = require("visuals.effects.effects")

local animation_types = require("visuals.render.animation_types")
local utils = require("utils")

local animation = {}

function animation.add_from_template(name, overrides)
	local new_anim = utils.create_instance_from_template(animation_types, name, overrides)
	return new_anim
end

function animation.spawn_pending_trail(entity)
	local pt = entity.pending_trail
	if not pt then
		return
	end
	local effect = effects:add_from_template("trail", pt.x, pt.y, pt.z)
	if pt.color then
		effect.rects[1].colors[1] = pt.color
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

function animation.update(dt)
	local tween_duration = (game_cfg.timing.turn_delay + render_cfg.tween_slack) * 0.5
	for _, entity in ipairs(entities.get_entity_list()) do
		if not entity.tween_x or not entity.tween_y then
			entity.tween_x = entity.x
			entity.tween_y = entity.y
			entity.tween_from_x = entity.x
			entity.tween_from_y = entity.y
			entity.tween_target_x = entity.x
			entity.tween_target_y = entity.y
			entity.tween_elapsed = tween_duration
		else
			if entity.tween_target_x ~= entity.x or entity.tween_target_y ~= entity.y then
				entity.tween_from_x = entity.tween_x
				entity.tween_from_y = entity.tween_y
				entity.tween_target_x = entity.x
				entity.tween_target_y = entity.y
				entity.tween_elapsed = 0
			end
			entity.tween_elapsed = math.min(entity.tween_elapsed + dt, tween_duration)
			local t = entity.tween_elapsed / tween_duration
			entity.tween_x = entity.tween_from_x + (entity.tween_target_x - entity.tween_from_x) * t
			entity.tween_y = entity.tween_from_y + (entity.tween_target_y - entity.tween_from_y) * t
		end

		entity.render_x = entity.tween_x
		entity.render_y = entity.tween_y

		if entity.pending_trail and entity.tween_elapsed >= 0.8 * tween_duration then
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
