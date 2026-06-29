local entity_types = require("entities.entity_types")
local event_log = require("engine.event_log")
local inventory = require("items.inventory")

local utils = require("utils")
local time = require("engine.time")
local game_config = require("config.game_config")

local entities = {
	entity_list = {},
	player = nil,
	by_cell = {},
}

function entities.set_player(p)
	entities.player = p
	for _, e in ipairs(entities.entity_list) do
		if e == p then
			return
		end
	end
	entities.add(p)
end

function entities.is_player(entity)
	return entity == entities.player
end

function entities.get_tag_location(x, y, z, tag)
	local ents = entities.get_list_at(x, y, z or 1)
	if not ents then
		return false
	end
	return utils.has_tag(ents, tag)
end

function entities.get_with_tag(x, y, z, tag)
	local ents = entities.get_list_at(x, y, z or 1)
	if not ents then
		return nil
	end
	return utils.find_with_tag(ents, tag)
end

function entities.interact(entity)
	local interaction = entity.interaction
	if not interaction then
		return
	end

	local toggle = interaction.toggle
	if toggle then
		for k, v in pairs(toggle) do
			if (k == "tags" or k == "appearance") and type(v) == "table" and type(entity[k]) == "table" then
				for sub_key, sub_val in pairs(v) do
					local old_val = entity[k][sub_key]
					entity[k][sub_key] = sub_val
					toggle[k][sub_key] = old_val
				end
			else
				entity[k], toggle[k] = v, entity[k]
			end
		end
	end
end

function entities.inspect(entity)
	if entity.description then
		event_log:add({ type = "describe", entity = entity.name, description = entity.description })
	end
end

local EMPTY = {}

local function cell_list(z, y, x, create)
	local zt = entities.by_cell[z]
	if not zt then
		if not create then
			return nil
		end
		zt = {}
		entities.by_cell[z] = zt
	end
	local yt = zt[y]
	if not yt then
		if not create then
			return nil
		end
		yt = {}
		zt[y] = yt
	end
	local xt = yt[x]
	if not xt then
		if not create then
			return nil
		end
		xt = {}
		yt[x] = xt
	end
	return xt
end

local function index_add(entity)
	for _, c in ipairs(utils.footprint_cells(entity)) do
		local list = cell_list(entity.z, c.y, c.x, true)
		list[#list + 1] = entity
	end
end

local function index_remove(entity)
	for _, c in ipairs(utils.footprint_cells(entity)) do
		local list = cell_list(entity.z, c.y, c.x, false)
		if list then
			utils.remove_from_list(list, entity)
		end
	end
end

function entities.get_list_at(x, y, z)
	return cell_list(z, y, x, false) or EMPTY
end

function entities.get_list_at_column(x, y) --TODO might come up for AOE esque things, need to dedup for big entities
	local result = {}
	for z = game_config.map.min_z, game_config.map.max_z do
		local list = cell_list(z, y, x, false)
		if list then
			for i = 1, #list do
				result[#result + 1] = list[i]
			end
		end
	end
	return result
end

function entities.move_to(entity, nx, ny, nz)
	index_remove(entity)
	entity.x = nx
	entity.y = ny
	entity.z = nz or entity.z
	entity.move_queue = entity.move_queue or {}
	table.insert(entity.move_queue, { x = entity.x, y = entity.y })
	index_add(entity)
end

---@return any entity
function entities.get_first(x, y, z)
	local list = cell_list(z, y, x, false)
	return list and list[1] or nil
end

function entities.remove(target)
	utils.remove_from_list(entities.entity_list, target)
	index_remove(target)
end

function entities.get_list()
	return entities.entity_list
end

function entities.add(entity)
	table.insert(entities.entity_list, entity)
	index_add(entity)

	if entity.type == "actor" then
		time.schedule_turn(entity)
	end
end

function entities.add_from_template(name, x, y, z, overrides)
	local new_entity = utils.create_instance_from_template(entity_types, name, overrides)

	utils.randomize_flicker(new_entity.light)

	new_entity.x = x or 1
	new_entity.y = y or 1
	new_entity.z = z or 1

	entities.add(new_entity)
	return new_entity
end

function entities.convert_item_to_pickup(x, y, z, item)
	local new_entity = entities.add_from_template(
		"item",
		x,
		y,
		z,
		{ appearance = { chars = item.chars, color = item.color }, item = item }
	)
	return new_entity
end

function entities.add_pickup_from_template(name, x, y, z, overrides)
	local new_item = inventory.create_from_template(name, overrides)
	return entities.convert_item_to_pickup(x, y, z, new_item)
end

function entities.hear(entity, sound, loudness)
	if entity.type ~= "actor" or not utils.get_tag(entity, "can_hear") then
		return
	end
	entity.mind = entity.mind or {}
	entity.mind.heard_sounds = entity.mind.heard_sounds or {}
	table.insert(entity.mind.heard_sounds, { sound = sound, loudness = loudness })
end

return entities
