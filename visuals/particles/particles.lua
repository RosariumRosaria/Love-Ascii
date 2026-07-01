local map = require("map.map")
local render_cfg = require("config.render_config")
local types = require("map.tile_types")
local entities = require("entities.entities")
local utils = require("utils")

local particles = {
	mode = "normal",
	particles = {},
	screen_w = 0,
	screen_h = 0,
	ceiling = 0,
}

local weather_modes = {
	rain = { char = ".", vz_min = -22, vz_max = -27, drift = 0, color = { 0.2, 0.25, 0.55, 0.7 }, linger = 1 },
	pipe = { char = "|", vz_min = -8, vz_max = -10, drift = 0, color = { 0.2, 0.25, 0.36, 0.5 }, linger = 1 },
	snow = { char = "*", vz_min = -1, vz_max = -2, drift = 0.5, color = { 1, 1, 1, 0.5 }, linger = 1 },
	normal = nil,
}

local particle_types = {
	smoke = {
		char = "*",
		vz_min = 4,
		vz_max = 5,
		drift = 0.2,
		color = { 0.5, 0.6, 0.6, 0.5 },
		linger = 4,
	},
	ember = {
		char = "`",
		vz_min = 1,
		vz_max = 2,
		drift = 0.35,
		r_rate = 60,
		color = { 0.9, 0.6, 0.2, 0.7 },
		linger = 1,
		lifespan = 4,
		gravity = 0.5,
	},
	blood = {
		char = ".",
		vz_min = 0,
		vz_max = 0,
		drift = 0.0,
		color = { 0.9, 0.3, 0.35, 0.7 },
		linger = 2,
		lifespan = 3,
		layer = "below_entity",
	},
	dust = {
		char = ",",
		vz_min = 0,
		vz_max = 0,
		drift = 0.0,
		color = { 0.3, 0.3, 0.35, 0.5 },
		linger = 2,
		r_rate = 30,
		lifespan = 3,
		layer = "below_entity",
	},
	dazed = {
		char = "?",
		vz_min = 1,
		vz_max = 2,
		drift = 0.35,
		r_rate = 20,
		color = { 0.9, 0.7, 0.2, 0.7 },
		linger = 2,
		lifespan = 3,
	},
	heal = {
		char = "+",
		vz_min = 1,
		vz_max = 2,
		drift = 0.35,
		r_rate = 20,
		color = { 0.2, 0.9, 0.4, 0.7 },
		linger = 2,
		lifespan = 3,
	},
}

local modes = { rain = "rain", snow = "snow", normal = "normal" }

local function weather_position(cx, cy, draw_dist)
	return cx + (math.random() * 2 - 1) * draw_dist,
		cy + (math.random() * 2 - 1) * draw_dist,
		particles.ceiling - math.random(0, 3)
end

local function spawn_particle(x, y, z, ease_in, params, source)
	if not params then
		return
	end

	return {
		x = x,
		y = y,
		z = z,
		vz = params.vz_min + math.random() * (params.vz_max - params.vz_min),
		vx = (math.random() * 2 - 1) * params.drift,
		vy = (math.random() * 2 - 1) * params.drift,
		linger = params.linger,
		linger_initial = params.linger,
		lifespan = params.lifespan,
		lifespan_initial = params.lifespan,
		alpha_mult = 1,
		r_rate = (params.r_rate or 0) * (0.25 + math.random()) * utils.randomize_sign(),
		r = params.r_rate and math.random() * 2 * math.pi or nil,
		char = params.char,
		color = params.color,
		gravity = params.gravity,
		layer = params.layer,
		delay = ease_in and math.random() * render_cfg.particles.weather_ease_in_duration or 0,
		source = source,
	}
end

function particles:burst(x, y, z, type_name, count, opts)
	local dir = opts.dir
	local spread = opts.spread or 0.2
	local smin = opts.smin or 10
	local smax = opts.smax or 16
	local popup = opts.popup or 1
	local gravity = opts.gravity or 3
	local base = dir and math.atan2(dir.dy, dir.dx) or math.random() * 2 * math.pi
	local params = particle_types[type_name]

	if not params then
		return
	end
	for _ = 1, count do
		local p = spawn_particle(x, y, z, false, params, "emitter")
		local a = base + (math.random() * 2 - 1) * spread
		local speed = smin + math.random() * (smax - smin)
		p.vx, p.vy = math.cos(a) * speed, math.sin(a) * speed
		p.vz = popup
		p.gravity = gravity
		table.insert(self.particles, p)
	end
end

function particles:load(cx, cy)
	self.ceiling = map.max_z * 3
	for _ = 1, render_cfg.particles.count do
		local wx, wy, wz = weather_position(cx, cy, render_cfg.camera.draw_distance)
		local p = spawn_particle(wx, wy, wz, true, weather_modes[self.mode], "weather")
		if p then
			table.insert(self.particles, p)
		end
	end
end

function particles:update(dt, cx, cy)
	local draw_dist = render_cfg.camera.draw_distance
	local weather_params = weather_modes[self.mode]

	if
		self.mode ~= modes.normal
		and #self.particles < render_cfg.particles.count * render_cfg.particles.weather_proportion
	then
		local wx, wy, wz = weather_position(cx, cy, draw_dist)
		local p = spawn_particle(wx, wy, wz, true, weather_params, "weather")
		if p then
			table.insert(self.particles, p)
		end
	end

	local emitter_count = 0
	for _, p in ipairs(self.particles) do
		if p.source == "emitter" then
			emitter_count = emitter_count + 1
		end
	end
	local emitter_cap = render_cfg.particles.count * (1 - render_cfg.particles.weather_proportion)

	local function run_emitters(list, ex, ey, base_z, default_offset)
		if not list then
			return 0
		end
		local spawned = 0
		for _, emitter in ipairs(list) do
			if math.random() < emitter.rate * dt then
				local ez = base_z + (emitter.z_offset or default_offset)
				local jx, jy = 0, 0
				if emitter.jitter then
					jx = -0.5 + math.random()
					jy = -0.5 + math.random()
				end

				local p = spawn_particle(ex + jx, ey + jy, ez, false, particle_types[emitter.particle], "emitter")
				if p then
					table.insert(self.particles, p)
					spawned = spawned + 1
				end
			end
		end
		return spawned
	end

	for _, entity in ipairs(entities.get_list()) do
		if emitter_count < emitter_cap then
			local ex = utils.render_x(entity)
			local ey = utils.render_y(entity)
			if math.abs(ex - cx) <= draw_dist and math.abs(ey - cy) <= draw_dist then
				local top_offset = entity.appearance and entity.appearance.chars and #entity.appearance.chars or 1
				emitter_count = emitter_count + run_emitters(entity.emitters, ex, ey, entity.z, top_offset)
				if entity.statuses then
					for _, status in ipairs(entity.statuses) do
						emitter_count = emitter_count + run_emitters(status.emitters, ex, ey, entity.z, top_offset)
					end
				end

				if entity.inventory and entity.inventory.equipped then
					for _, item in pairs(entity.inventory.equipped) do
						emitter_count = emitter_count + run_emitters(item.emitters, ex, ey, entity.z, top_offset)
					end
				end
			end
		end
	end

	for i, p in ipairs(self.particles) do
		if p.delay > 0 then
			p.delay = p.delay - dt
		else
			p.x = p.x + p.vx * dt
			p.y = p.y + p.vy * dt
			p.z = p.z + p.vz * dt
			p.vz = p.vz - ((p.gravity or 0) * dt)
			p.r = (p.r or 0) + ((p.r_rate or 0) * dt)
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

			if p.lifespan then
				p.lifespan = p.lifespan - dt
			end

			local kill = hit
				or p.z < map.min_z
				or out_x
				or out_y
				or (p.vz > 0 and p.z > self.ceiling)
				or (p.lifespan and p.lifespan <= 0)
			if kill then
				if hit then
					p.vz, p.vx, p.vy = 0, 0, 0
				end
				p.linger = p.linger - dt
			end

			local life_ratio = (p.lifespan_initial and p.lifespan_initial > 0)
					and math.max(0, p.lifespan / p.lifespan_initial)
				or 1
			local linger_ratio = (p.linger_initial > 0) and math.max(0, p.linger / p.linger_initial) or 1
			p.alpha_mult = math.min(life_ratio, linger_ratio)

			if kill and (p.linger <= 0 or (p.lifespan and p.lifespan <= 0)) then
				local new_p = nil
				if p.source == "weather" then
					local wx, wy, wz = weather_position(cx, cy, draw_dist)
					new_p = spawn_particle(wx, wy, wz, false, weather_params, "weather")
				end
				if new_p then
					self.particles[i] = new_p
				else
					local last = #self.particles
					self.particles[i] = self.particles[last]
					self.particles[last] = nil
				end
			end
		end
	end
end

function particles:set_mode(weather_mode)
	self.particles = {}
	self.mode = modes[weather_mode]
end

function particles:get_particles()
	return self.particles
end

return particles
