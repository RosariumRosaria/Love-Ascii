local game_cfg = require("config.game_config")
local entities = require("entities.entities")
local effects = require("visuals.effects.effects")
local camera = require("visuals.camera")

local animation_types = require("visuals.render.animation_types")
local utils = require("utils")

local animation = {}

local TWEEN_SLACK = 0.1
local jitter_prev_rx, jitter_prev_ry
local jitter_prev_sx, jitter_prev_sy
local jitter_logged_slack = false

function animation.add_from_template(name, overrides)
	local new_anim = utils.create_instance_from_template(animation_types, name, overrides)
	return new_anim
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
	local tween_duration = game_cfg.timing.turn_delay + TWEEN_SLACK
	if not jitter_logged_slack then
		print(string.format("[jitter] TWEEN_SLACK=%.4f tween_duration=%.4f", TWEEN_SLACK, tween_duration))
		jitter_logged_slack = true
	end
	for _, entity in ipairs(entities.get_entity_list()) do
		if not entity.render_x or not entity.render_y then
			entity.render_x = entity.x
			entity.render_y = entity.y
			entity.tween_from_x = entity.x
			entity.tween_from_y = entity.y
			entity.tween_target_x = entity.x
			entity.tween_target_y = entity.y
			entity.tween_elapsed = tween_duration
		else
			if entity.tween_target_x ~= entity.x or entity.tween_target_y ~= entity.y then
				entity.tween_from_x = entity.render_x
				entity.tween_from_y = entity.render_y
				entity.tween_target_x = entity.x
				entity.tween_target_y = entity.y
				entity.tween_elapsed = 0
			end
			entity.tween_elapsed = math.min(entity.tween_elapsed + dt, tween_duration)
			local t = entity.tween_elapsed / tween_duration
			entity.render_x = entity.tween_from_x + (entity.tween_target_x - entity.tween_from_x) * t
			entity.render_y = entity.tween_from_y + (entity.tween_target_y - entity.tween_from_y) * t
		end

		if entity == entities.player then
			local cx, cy = camera:get_position()
			cx = cx or 0
			cy = cy or 0
			local sx = entity.render_x - cx
			local sy = entity.render_y - cy
			local dRx = jitter_prev_rx and (entity.render_x - jitter_prev_rx) or 0
			local dRy = jitter_prev_ry and (entity.render_y - jitter_prev_ry) or 0
			local dSx = jitter_prev_sx and (sx - jitter_prev_sx) or 0
			local dSy = jitter_prev_sy and (sy - jitter_prev_sy) or 0
			local vRx = dt > 0 and dRx / dt or 0
			local vSx = dt > 0 and dSx / dt or 0
			local stuck = math.abs(dRx) < 1e-6 and math.abs(dRy) < 1e-6
			print(
				string.format(
					"[jitter] dt=%.4f dRx=%+.5f dRy=%+.5f vRx=%+6.3f dSx=%+.5f dSy=%+.5f vSx=%+6.3f%s",
					dt,
					dRx,
					dRy,
					vRx,
					dSx,
					dSy,
					vSx,
					stuck and " STUCK" or ""
				)
			)
			jitter_prev_rx, jitter_prev_ry = entity.render_x, entity.render_y
			jitter_prev_sx, jitter_prev_sy = sx, sy
		end

		local pt = entity.pending_trail
		if pt and math.floor(entity.render_x + 0.5) == entity.x and math.floor(entity.render_y + 0.5) == entity.y then
			local effect = effects:add_from_template("trail", pt.x, pt.y, pt.z)
			if pt.color then
				effect.rects[1].colors[1] = pt.color
			end
			entity.pending_trail = nil
		end

		if entity.bump then
			entity.bump.elapsed = entity.bump.elapsed + dt
			if entity.bump.elapsed >= entity.bump.duration then
				entity.bump = nil
			else
				local p = entity.bump.elapsed / entity.bump.duration -- 0 to 1
				local curve = math.sin(p * math.pi) -- 0 -> 1 -> 0
				entity.render_x = entity.render_x + entity.bump.dx * curve
				entity.render_y = entity.render_y + entity.bump.dy * curve
			end
		end
	end
end

return animation
