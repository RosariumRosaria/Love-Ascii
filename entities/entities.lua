local entity_types = require("entities.entity_types")
local ui_handler = require("visuals.ui")
local utils = require("utils")

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

function entities:damage_entity(target_entity, entity)
	if
		not entity
		or not target_entity
		or not target_entity.stats
		or not target_entity.stats.health
		or not entity.damage
	then
		return false
	end

	target_entity.stats.health.health = target_entity.stats.health.health - entity.damage
	local target_name = target_entity.name or "Unnamed"
	local name = entity.name or "Unnamed"
	ui_handler:add_text_to_ui_by_name(
		"terminal",
		name .. " hit " .. target_name .. ": " .. target_entity.stats.health.health .. " HP remaining!"
	)

	if target_entity.stats.health.health <= 0 then
		target_entity.dead = true
		self:remove_entity(target_entity)
	end
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
		ui_handler:add_text_to_ui_by_name("terminal", entity.description)
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

function entities:describe(entity)
	if not entity then
		ui_handler:add_text_to_ui_by_name("terminal", "Entity is nil!")
		return false
	end
	for k, v in pairs(entity) do
		ui_handler:add_text_to_ui_by_name("terminal", "key: " .. tostring(k) .. "value: " .. tostring(v))
	end
end

return entities
