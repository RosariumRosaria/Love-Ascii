local item_types = require("entities.item_types")
local statuses = require("entities.statuses")
local utils = require("utils")

local inventory = {}
local inventory_template = {
	items = {},
	equipped = { armor = nil, offhand = nil, accessory = nil, mainhand = nil },
}

function inventory.get_item(entity, key)
	if not entity.inventory then
		return nil
	end

	for _, item in ipairs(entity.inventory.items) do
		if item.key == key then
			return item
		end
	end
	return nil
end

function inventory.add_item(entity, name, overrides)
	if not entity.inventory then
		entity.inventory = utils.deep_copy(inventory_template)
	end
	local new_item = item_types[name]
	if not new_item then
		error("Item '" .. tostring(name) .. "' does not exist")
	end

	if overrides then
		for k, v in pairs(overrides) do
			new_item[k] = v
		end
	end

	if not new_item.key then
		new_item.key = name or new_item.name
	end

	table.insert(entity.inventory.items, new_item)
end

function inventory.remove_item(entity, key)
	if not entity.inventory then
		return
	end
	for i, item in ipairs(entity.inventory) do
		if item.key == key then
			table.remove(entity.inventory, i)
			return
		end
	end
end

function inventory.equip(entity, key)
	if not entity.inventory then
		return
	end
	local item = inventory.get_item(entity, key)
	if not item then
		error("Item '" .. tostring(key) .. "' not found in inventory")
	end

	local slot = item.slot
	if not slot then
		error("Item '" .. tostring(key) .. "' cannot be equipped")
	end
	if entity.inventory.equipped[slot] then
		inventory.unequip(entity, slot)
	end
	entity.inventory.equipped[slot] = item
end

function inventory.unequip(entity, slot)
	if not entity.inventory then
		return
	end
	if not entity.inventory.equipped[slot] then
		error("Slot '" .. tostring(slot) .. "' is not equipped")
	end

	entity.inventory.equipped[slot] = nil
end

function inventory.is_equipped(entity, key)
	if not entity.inventory then
		return false
	end
	for _, equipped_item in pairs(entity.inventory.equipped) do
		if equipped_item and equipped_item.key == key then
			return true
		end
	end
	return false
end

function inventory:use(entity, idx)
	local item = entity.inventory.items[idx]
	if item.on_use.apply_status then
		statuses.add_status(entity, item.on_use.apply_status)
	end
end

return inventory
