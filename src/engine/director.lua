local entities = require("src.sim.entities")
local map = require("src.map.map")
local tile_types = require("src.map.tile_types")
local utils = require("src.utils")
local event_log = require("src.engine.event_log")
local ai = require("src.engine.ai")
local entity_types = require("src.sim.entity_types")
local debug_state = require("src.debug.debug_state")
local pathfinder = require("src.engine.pathfinder")
local director = {}

local actor_cap = 100

local max_spawn_tries = 20
local max_path_checks = 5

local spawn_list = {
	{ name = "zombie", price = 20, weight = 10 },
	{ name = "shambler", price = 20, weight = 10 },
	{ name = "skeleton", price = 30, weight = 6 },
	{ name = "vampire", price = 40, weight = 6 },
	{ name = "ogre", price = 60, weight = 2 },
}

local modifiers = {
	{ name = "normal", price = 0, weight = 30 },
	{ name = "hunter", price = 10, weight = 10 },
}

local pack_sizes = {
	{ size = 1, weight = 10 },
	{ size = 2, weight = 5 },
	{ size = 3, weight = 2 },
}

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
	for i = 1, max_spawn_tries do
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
			if path_checks >= max_path_checks then
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
	for i = 1, max_spawn_tries do
		local pack_size = utils.pick_weighted(pack_sizes)
		if pack_size then
			local pack = {}
			for ii = 1, pack_size.size do
				local entity_type = utils.pick_weighted(spawn_list)
				local modifier = utils.pick_weighted(modifiers)
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
		if modifier == "hunter" then
			local player = entities.player
			ai:set_goal(ent.id, { kind = "investigate", x = player.x, y = player.y })
		end
		return ent
	end
end

local min_spawn_range = 20
local max_spawn_range = 60
local min_pack_spawn_range = 1
local max_pack_spawn_range = 10

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
	local leader_spawn =
		spawn_member(entities.player, leader.ent.name, leader.mod.name, min_spawn_range, max_spawn_range)
	if leader_spawn then
		table.insert(spawned, leader)

		for _, member in ipairs(pack) do
			if member ~= leader then
				local member_spawn = spawn_member(
					leader_spawn,
					member.ent.name,
					member.mod.name,
					min_pack_spawn_range,
					max_pack_spawn_range
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
local dread_inc = 1
local min_dread_spawn = 40
local max_dread_spawn = 200
local min_spawn_chance = 1
local max_spawn_chance = 100

local function spawn_chance()
	local t = utils.clamp((dread - min_dread_spawn) / (max_dread_spawn - min_dread_spawn), 0, 1)
	return utils.lerp(min_spawn_chance, max_spawn_chance, t)
end

function director:tick()
	dread = dread + dread_inc
	if dread >= min_dread_spawn and #entities.get_actors() <= actor_cap and utils.chance(spawn_chance()) then
		local spawned = spawn_pack(build_pack(dread))
		if spawned then
			dread = dread - price_pack(spawned)
		end
	end
end

return director
