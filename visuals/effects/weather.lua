local map = require("map.map")
local render_cfg = require("config.render_config")
local types = require("map.tile_types")
local utils = require("utils")
local weather = {
	mode = "rain",
	particles = {},
	screen_w = 0,
	screen_h = 0, --TODO GENERALIZE INTO PARTICLES, FOR EXAMPLE SMOKE
}
local mode_params = {
	rain = { char = ".", vz_min = -22, vz_max = -27, drift = 0, color = { 0.2, 0.25, 0.66, 0.7 } },
	pipe = { char = "|", vz_min = -8, vz_max = -10, drift = 0, color = { 0.2, 0.25, 0.36, 0.5 } },
	snow = { char = "*", vz_min = -1, vz_max = -2, drift = 0.5, color = { 1, 1, 1, 0.5 } },
	normal = nil,
}
local modes = { rain = "rain", snow = "snow", normal = "normal" }

local function spawn_particle(cx, cy, draw_dist, ease_in)
	local params = mode_params[weather.mode]

	if not params then
		return
	end
	return {
		x = cx + (math.random() * 2 - 1) * draw_dist,
		y = cy + (math.random() * 2 - 1) * draw_dist,
		z = map.max_z + 10 + math.random(1, 5),
		vz = params.vz_min + math.random() * (params.vz_max - params.vz_min),
		vx = (math.random() * 2 - 1) * params.drift,
		vy = (math.random() * 2 - 1) * params.drift,
		linger = 1,
		char = params.char,
		color = params.color,
		delay = ease_in and math.random() * render_cfg.weather_ease_in_duration or 0,
	}
end

function weather:load(cx, cy)
	for _ = 1, render_cfg.particle_count do
		local p = spawn_particle(cx, cy, render_cfg.draw_distance, true)
		table.insert(self.particles, p)
	end
end

function weather:update(dt, cx, cy)
	local draw_dist = render_cfg.draw_distance

	if self.mode ~= modes.normal and #self.particles < render_cfg.particle_count then
		local p = spawn_particle(cx, cy, draw_dist, true)
		if p then
			table.insert(self.particles, p)
		end
	end

	for i, p in ipairs(self.particles) do
		if p.delay > 0 then
			p.delay = p.delay - dt
		else
			p.x = p.x + p.vx * dt
			p.y = p.y + p.vy * dt
			p.z = p.z + p.vz * dt
			local tx, ty = math.floor(p.x), math.floor(p.y)
			local hit = false
			if map:in_bounds(tx, ty) then
				local tile = map:get_tile(tx, ty, math.floor(p.z))
				if tile and tile ~= types.air then
					hit = true
				end
			end
			local out_x = math.abs(p.x - cx) > draw_dist
			local out_y = math.abs(p.y - cy) > draw_dist
			if hit or p.z < map.min_z or out_x or out_y then
				p.vz, p.vx, p.vy = 0, 0, 0

				p.linger = p.linger - dt
				if p.linger <= 0 then
					self.particles[i] = spawn_particle(cx, cy, draw_dist, false)
				end
			end
		end
	end
end

function weather:set_mode(weather_mode)
	self.particles = {}
	self.mode = modes[weather_mode]
end

function weather:get_particles()
	return self.particles
end

return weather
