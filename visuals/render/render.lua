local effects = require("visuals.effects.effects")
local ui_handler = require("visuals.ui")
local entities = require("entities.entities")
local render_utils = require("visuals.render.utils")
local map = require("map.map")
local render_primitives = require("visuals.render.primitives")
local render_cfg = require("config.render_config")
local camera = require("visuals.camera")
local painter = require("visuals.render.painter")
local draw_buffer = require("visuals.render.draw_buffer")
local weather = require("visuals.effects.weather")
local game_cfg = require("config.game_config")
local render = {}

function render:draw()
	local draw_dist = render_cfg.draw_distance
	local camera_x, camera_y = camera:get_position()

	--Draw Map
	local cx = math.floor(camera_x or 0)
	local cy = math.floor(camera_y or 0)
	local end_x = math.min(cx + draw_dist, map:get_max_x())
	local end_y = math.min(cy + draw_dist, map:get_max_y())
	local start_x = math.max(cx - draw_dist, 1)
	local start_y = math.max(cy - draw_dist, 1)
	local start_z = map.min_z
	local end_z = map.max_z
	local tiles = map:get_tiles()
	local time = love.timer.getTime()
	draw_buffer:clear()
	for z = start_z, end_z do
		for y = start_y, end_y do
			for x = start_x, end_x do
				painter:emit_tile_at_z(
					tiles[y][x][z],
					x,
					y,
					z,
					camera_x,
					camera_y,
					map:is_visible(x, y),
					map:is_explored(x, y),
					time
				)
			end
		end
	end

	for _, entity in ipairs(entities.get_entity_list()) do
		painter:emit_entity(
			entity,
			camera_x,
			camera_y,
			map:is_visible(entity.x, entity.y),
			map:is_explored(entity.x, entity.y),
			time
		)
	end

	for _, p in ipairs(weather:get_particles()) do
		painter:emit_weather_particle(p, camera_x, camera_y, time)
	end

	for _, effect in ipairs(effects:get_effect_list()) do
		if effect.params.buffered then
			painter:emit_effect(effect, camera_x, camera_y, map:is_visible(effect.x, effect.y))
		end
	end

	draw_buffer:sort()
	draw_buffer:walk()

	painter:draw_grid_overlay(start_x, start_y, end_x, end_y, camera_x, camera_y)

	--Draw Effects
	for _, effect in ipairs(effects:get_effect_list()) do
		if not effect.params.buffered then
			painter:draw_effect(effect, camera_x, camera_y, map:is_visible(effect.x, effect.y))
		end
	end

	for _, ui in ipairs(ui_handler:get_ui_list()) do
		painter:draw_ui(ui)
	end
end

function render:reload_fonts()
	render_utils.load()
	render_primitives.load()
	ui_handler:reload_fonts()
	painter:reload_fonts()
end

function render:load(player_x, player_y)
	camera:load(player_x, player_y)
	painter:reload_settings()
	local cx, cy = camera:get_position()
	weather:load(cx, cy)
end

function render:update(target_x, target_y, dt)
	local turn_delay = game_cfg.timing.turn_delay
	for _, entity in ipairs(entities.get_entity_list()) do
		if not entity.render_x or not entity.render_y then
			entity.render_x = entity.x
			entity.render_y = entity.y
			entity.tween_from_x = entity.x
			entity.tween_from_y = entity.y
			entity.tween_target_x = entity.x
			entity.tween_target_y = entity.y
			entity.tween_elapsed = turn_delay
		else
			if entity.tween_target_x ~= entity.x or entity.tween_target_y ~= entity.y then
				entity.tween_from_x = entity.render_x
				entity.tween_from_y = entity.render_y
				entity.tween_target_x = entity.x
				entity.tween_target_y = entity.y
				entity.tween_elapsed = 0
			end
			entity.tween_elapsed = math.min(entity.tween_elapsed + dt, turn_delay)
			local t = entity.tween_elapsed / turn_delay
			entity.render_x = entity.tween_from_x + (entity.tween_target_x - entity.tween_from_x) * t
			entity.render_y = entity.tween_from_y + (entity.tween_target_y - entity.tween_from_y) * t
		end

		local pt = entity.pending_trail
		if pt and math.floor(entity.render_x + 0.5) == entity.x and math.floor(entity.render_y + 0.5) == entity.y then
			local effect = effects:add_from_template("trail", pt.x, pt.y, pt.z)
			if pt.color then
				effect.rects[1].colors[1] = pt.color
			end
			entity.pending_trail = nil
		end
	end
	camera:update(target_x, target_y, dt)
	local cx, cy = camera:get_position()
	weather:update(dt, cx, cy)
end

return render
