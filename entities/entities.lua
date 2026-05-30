local entity_types = require("entities.entity_types")
local event_log = require("engine.event_log")
local inventory = require("items.inventory")

local utils = require("utils")
local scheduler = require("engine.scheduler")
local stats = require("stats.stats")

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
	entities.add_entity(p)
end

function entities.is_player(entity)
	return entity == entities.player
end

function entities.get_tag_location(x, y, z, tag)
	local ents = entities.get_entities_at(x, y, z or 1)
	if not ents then
		return false
	end

	for _, ent in ipairs(ents) do
		if entities.get_tag_entity(ent, tag) then
			return true
		end
	end

	return false
end

function entities.get_tag_entity(entity, tag)
	return entity.tags[tag]
end

function entities.apply_damage(target, amount, source_name)
	if not target.stats or not target.stats.health then
		return nil
	end
	local before = stats.get_current(target, "health")
	stats.set_current(target, "health", before - amount)
	local after = stats.get_current(target, "health")
	event_log:add({ type = "damage", entity = target.name, source = source_name, amount = amount })

	local killed = after <= 0

	if killed then
		target.dead = true
		event_log:add({ type = "entity_died", entity = target.name, source = source_name })
		entities.remove_entity(target)
	end
end

function entities.apply_heal(target, amount, source_name)
	if not target.stats or not target.stats.health then
		return nil
	end
	local before = stats.get_current(target, "health")
	stats.set_current(target, "health", before + amount)

	event_log:add({ type = "heal", entity = target.name, source = source_name, amount = amount })
end

function entities.interact_with_entity(entity)
	local interaction = entity.interaction
	if not interaction then
		return
	end

	local toggle = interaction.toggle
	if toggle then
		for k, v in pairs(toggle) do
			if k == "tags" and type(v) == "table" and type(entity[k]) == "table" then
				for tag_key, tag_val in pairs(v) do
					local old_val = entity[k][tag_key]
					entity[k][tag_key] = tag_val
					toggle[k][tag_key] = old_val
				end
			else
				entity[k], toggle[k] = v, entity[k]
			end
		end
	end
end

function entities.inspect_entity(entity)
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
	local list = cell_list(entity.z, entity.y, entity.x, true)
	list[#list + 1] = entity
end

local function index_remove(entity)
	local list = cell_list(entity.z, entity.y, entity.x, false)
	if list then
		utils.remove_from_list(list, entity)
	end
end

function entities.get_entities_at(x, y, z)
	return cell_list(z, y, x, false) or EMPTY
end

function entities.move_to(entity, nx, ny, nz)
	index_remove(entity)
	entity.x = nx
	entity.y = ny
	entity.z = nz or entity.z
	index_add(entity)
end

---@return any entity
function entities.get_entity(x, y, z)
	local list = cell_list(z, y, x, false)
	return list and list[1] or nil
end

function entities.remove_entity(target)
	utils.remove_from_list(entities.entity_list, target)
	index_remove(target)
end

function entities.get_entity_list()
	return entities.entity_list
end

function entities.add_entity(entity)
	table.insert(entities.entity_list, entity)
	index_add(entity)

	if entity.type == "actor" then
		scheduler.schedule_turn(entity)
	end
end

function entities.add_from_template(name, x, y, z, overrides)
	local new_entity = utils.create_instance_from_template(entity_types, name, overrides)

	utils.randomize_flicker(new_entity.light)

	new_entity.x = x or 1
	new_entity.y = y or 1
	new_entity.z = z or 1

	entities.add_entity(new_entity)
	return new_entity
end

function entities.convert_item_to_pickup(x, y, z, item)
	local new_entity =
		entities.add_from_template("item", x, y, z, { chars = item.chars, color = item.color, item = item })
	return new_entity
end

function entities.add_pickup_from_template(name, x, y, z, overrides)
	local new_item = inventory.create_item_from_template(name, overrides)
	return entities.convert_item_to_pickup(x, y, z, new_item)
end

return entities
