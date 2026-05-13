local entity_types = require("entities.entity_types")
local event_log = require("engine.event_log")

local utils = require("utils")
local scheduler = require("engine.scheduler")
local stats = require("entities.stats")

local entities = {
	entity_list = {},
	player = nil,
	entities_by_z_level = {},
}

function entities:set_player(p)
	self.player = p
	for _, e in ipairs(self.entity_list) do
		if e == p then
			return
		end
	end
	self:add_entity(p)
end

function entities:is_player(entity)
	return entity == self.player
end

function entities:get_tag_location(x, y, z, tag)
	local entity = entities:get_entity(x, y, z or 1)
	if not entity then
		return false
	end

	return entities:get_tag_entity(entity, tag)
end

function entities:get_tag_entity(entity, tag)
	return entity.tags[tag]
end

function entities:apply_damage(target, amount, source_name)
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
		entities:remove_entity(target)
	end
end

function entities:apply_heal(target, amount, source_name)
	if not target.stats or not target.stats.health then
		return nil
	end
	local before = stats.get_current(target, "health")
	stats.set_current(target, "health", before + amount)

	event_log:add({ type = "heal", entity = target.name, source = source_name, amount = amount })
end

function entities:interact_with_entity(entity)
	local interaction = entity.interaction
	if not interaction then
		return
	end

	for k, v in pairs(interaction) do
		if k == "tags" and type(v) == "table" and type(entity[k]) == "table" then
			for tag_key, tag_val in pairs(v) do
				local old_val = entity[k][tag_key]
				entity[k][tag_key] = tag_val
				interaction[k][tag_key] = old_val
			end
		else
			entity[k], interaction[k] = v, entity[k]
		end
	end
end

function entities:inspect_entity(entity)
	if entity.description then
		event_log:add({ type = "describe", entity = entity.name, description = entity.description })
	end
end

function entities:get_entity(x, y, z)
	for _, entity in ipairs(self.entity_list) do
		if entity.x == x and entity.y == y and entity.z == z then
			return entity
		end
	end
end

function entities:remove_entity(target)
	for i, entity in ipairs(self.entity_list) do
		if entity == target then
			table.remove(self.entity_list, i)
			break
		end
	end

	local z_list = self.entities_by_z_level[target.z]
	if z_list then
		for i, entity in ipairs(z_list) do
			if entity == target then
				table.remove(z_list, i)
				break
			end
		end

		if #z_list == 0 then
			self.entities_by_z_level[target.z] = nil
		end
	end

	return true
end

function entities:get_entity_list_by_z_level(z)
	return self.entities_by_z_level[z] or {}
end

function entities:get_entity_list()
	return self.entity_list
end

function entities:add_entity(entity)
	table.insert(self.entity_list, entity)

	local z = entity.z

	if not self.entities_by_z_level[z] then
		self.entities_by_z_level[z] = {}
	end

	table.insert(self.entities_by_z_level[z], entity)

	if entity.type == "actor" then
		scheduler.schedule_turn(entity)
	end
end

function entities:add_from_template(name, x, y, z, overrides)
	local template = entity_types[name]
	if not template then
		error("Entity type '" .. tostring(name) .. "' does not exist")
	end
	local new_entity = utils.deep_copy(template)

	new_entity.x = x or 1
	new_entity.y = y or 1
	new_entity.z = z or 1

	if overrides then
		for k, v in pairs(overrides) do
			new_entity[k] = v
		end
	end

	self:add_entity(new_entity)
	return new_entity
end

return entities
