local entities = require("src.sim.entities")
local map = require("src.map.map")
local tile_types = require("src.map.tile_types")
local utils = require("src.utils")
local event_log = require("src.engine.event_log")
local ai = require("src.engine.ai")
local entity_types = require("src.sim.entity_types")
local debug_state = require("src.debug.debug_state")
local pathfinder = require("src.engine.pathfinder")
local time = require("src.engine.time")
local effects = require("src.visuals.effects.effects")
local director_config = require("src.config.director_config")
local director = {}

local function make_probe(name)
	local probe = utils.create_instance_from_template(entity_types, name)
	if probe then
		probe.mind = probe.mind or {}
		probe.mind.avoid = probe.mind.avoid or {}
	end
	return probe
end

local function can_reach_anchor(probe, sx, sy, ax, ay)
	probe.x, probe.y, probe.z = sx, sy, 1
	return pathfinder.can_reach(probe, { x = sx, y = sy }, { x = ax, y = ay })
end

local function find_viable_spot(ox, oy, min_range, max_range, template)
	local path_checks = 0
	for i = 1, director_config.max_spawn_tries do
		local major = love.math.random(min_range, max_range)
		local minor = love.math.random(0, max_range)
		local x, y = major, minor
		if love.math.random(2) == 1 then
			x, y = minor, major
		end
		local sx = ox + (x * utils.randomize_sign())
		local sy = oy + (y * utils.randomize_sign())
		if
			map:in_bounds(sx, sy)
			and not map:is_visible(sx, sy)
			and map:get_tile(sx, sy, 1) == tile_types.grass
			and map:is_footprint_free(sx, sy, 1, template)
		then
			if path_checks >= director_config.max_path_checks then
				return
			end
			path_checks = path_checks + 1
			if can_reach_anchor(template, sx, sy, ox, oy) then
				return sx, sy
			end
		end
	end
end

local function price_member(member)
	local price = 0
	if member.ent and member.ent.price then
		local mod_price = (member.mod and member.mod.price) or 0
		price = price + member.ent.price + mod_price
	end
	return price
end

local function price_pack(pack)
	local price = 0
	for _, member in ipairs(pack) do
		price = price + price_member(member)
	end
	return price
end

local function build_pack(budget)
	for i = 1, director_config.max_spawn_tries do
		local pack_size = utils.pick_weighted(director_config.pack_sizes)
		if pack_size then
			local pack = {}
			for ii = 1, pack_size.size do
				local entity_type = utils.pick_weighted(director_config.spawn_list)
				local modifier = utils.pick_weighted(director_config.modifiers)
				table.insert(pack, { ent = entity_type, mod = modifier })
			end
			if price_pack(pack) < budget then
				return pack
			end
		end
	end
end

local function spawn_member(origin, entity, modifier, min_range, max_range)
	local probe = make_probe(entity)
	if not probe then
		return
	end
	local x, y = find_viable_spot(origin.x, origin.y, min_range, max_range, probe)
	if x and y then
		local ent = entities.add_from_template(entity, x, y, 1)
		ent.mind.director = true -- TODO someday these both should maybe go? I just wanted to be able to keep track of who made whatW
		if modifier == "hunter" then
			local player = entities.player
			ai:set_goal(ent.id, { kind = "investigate", x = player.x, y = player.y, value = 12, turns = 70 })
			ent.mind.hunter = true
		end
		return ent
	end
end

local function log_pack(pack, leader_spawn)
	if not debug_state.log_director then
		return
	end
	event_log:add({
		type = "debug",
		message = "Spawned pack at: " .. leader_spawn.x .. ", " .. leader_spawn.y,
	})
	for _, member in ipairs(pack) do
		event_log:add({
			type = "debug",
			message = "  " .. member.mod.name .. " " .. member.ent.name,
		})
	end
end

local function spawn_pack(pack)
	if not pack or #pack < 1 then
		return
	end

	local leader = pack[1]

	for _, member in ipairs(pack) do
		if price_member(member) > price_member(leader) then
			leader = member
		end
	end

	local spawned = {}
	local leader_spawn = spawn_member(
		entities.player,
		leader.ent.name,
		leader.mod.name,
		director_config.min_spawn_range,
		director_config.max_spawn_range
	)
	if leader_spawn then
		table.insert(spawned, leader)

		for _, member in ipairs(pack) do
			if member ~= leader then
				local member_spawn = spawn_member(
					leader_spawn,
					member.ent.name,
					member.mod.name,
					director_config.min_pack_spawn_range,
					director_config.max_pack_spawn_range
				)
				if member_spawn then
					table.insert(spawned, member)
				end
			end
		end

		log_pack(spawned, leader_spawn)
	end

	return spawned
end

local dread = 0

function director:get_dread()
	return dread
end

local function local_pressure(player, range)
	local n = 0
	local px, py = player.x, player.y
	for _, actor in ipairs(entities.get_actors()) do
		if
			actor ~= player
			and not actor.dead
			and math.abs(actor.x - px) <= range
			and math.abs(actor.y - py) <= range
		then
			n = n + 1
		end
	end
	return n
end

function director:get_pressure(range)
	local player = entities.player
	if not player then
		return 0
	end
	return local_pressure(player, range or director_config.spawn_pressure_range)
end

function director:reap()
	local player = entities.player
	if not player then
		return 0
	end

	local range = director_config.reap_range
	local actors = entities.get_actors()
	local reaped = 0

	for i = #actors, 1, -1 do
		local actor = actors[i]
		if
			actor.mind
			and actor.mind.director
			and not actor.dead
			and (math.abs(actor.x - player.x) > range or math.abs(actor.y - player.y) > range)
		then
			time.remove(actor)
			effects:remove_anchored(actor)
			entities.remove(actor)
			reaped = reaped + 1
		end
	end

	if reaped > 0 and debug_state.log_director then
		event_log:add({ type = "debug", message = "Reaped " .. reaped .. " director actors" })
	end

	return reaped
end

local function spawn_chance()
	local cfg = director_config
	local t = utils.clamp((dread - cfg.min_dread_spawn) / (cfg.max_dread_spawn - cfg.min_dread_spawn), 0, 1)
	return utils.lerp(cfg.min_spawn_chance, cfg.max_spawn_chance, t)
end

function director:tick()
	local cfg = director_config

	director:reap()

	local near = director:get_pressure(cfg.dread_pressure_range)
	local ramp = utils.clamp((cfg.dread_pressure_cap - near) / cfg.dread_pressure_cap, 0, 1)
	dread = utils.clamp(dread + cfg.dread_inc * ramp, 0, cfg.max_dread_spawn)

	if
		dread >= cfg.min_dread_spawn
		and director:get_pressure() <= cfg.spawn_actor_cap
		and utils.chance(spawn_chance())
	then
		local spawned = spawn_pack(build_pack(dread))
		if spawned then
			dread = dread - price_pack(spawned)
		end
	end
end

return director
