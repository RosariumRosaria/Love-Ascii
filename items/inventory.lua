local item_types = require("items.item_types")
local utils = require("utils")

local game_cfg = require("config.game_config")

local inventory = {}
local inventory_template = {
	items = {},
	equipped = { armor = nil, offhand = nil, accessory = nil, mainhand = nil },
	selected_index = nil,
}

function inventory.get_equipped(entity, slot)
	if not entity or not entity.inventory then
		return nil
	end

	if not slot then
		return entity.inventory[slot]
	end

	return entity.inventory.equipped[slot]
end

function inventory.increment_selected_index(entity)
	if not entity.inventory or #entity.inventory.items == 0 then
		return
	end
	if not entity.inventory.selected_index then
		entity.inventory.selected_index = 1
	else
		entity.inventory.selected_index = entity.inventory.selected_index + 1
		if entity.inventory.selected_index > #entity.inventory.items then
			entity.inventory.selected_index = 1
		end
	end
end

function inventory.set_selected_index(entity, index)
	if not entity.inventory or index < 1 or #entity.inventory.items < index then
		return
	end
	entity.inventory.selected_index = index
end

function inventory.add(entity, item)
	if not entity.inventory then
		entity.inventory = utils.deep_copy(inventory_template)
	end
	if utils.get_tag(item, "stacks") and item.charges then
		local cap = item.max_charges or game_cfg.inventory.max_stack_limit
		local existing_item = inventory.get_with_name_where_not_full(entity, item.name)
		while existing_item and item.charges > 0 do
			item.charges = inventory.merge_stacks(existing_item, item.charges)
			existing_item = inventory.get_with_name_where_not_full(entity, item.name)
		end
		while item.charges > cap do
			local overflow = utils.deep_copy(item)
			overflow.charges = cap
			table.insert(entity.inventory.items, overflow)
			item.charges = item.charges - cap
		end
		if item.charges > 0 then
			table.insert(entity.inventory.items, item)
		end
	else
		table.insert(entity.inventory.items, item)
	end
end

function inventory.create_from_template(name, overrides)
	local new_item = utils.create_instance_from_template(item_types, name, overrides)
	utils.randomize_flicker(new_item.light)
	return new_item
end

function inventory.add_from_template(entity, name, overrides)
	local new_item = inventory.create_from_template(name, overrides)
	inventory.add(entity, new_item)
	return new_item
end

function inventory.remove(entity, item)
	if not entity.inventory then
		return
	end
	for i, i_item in ipairs(entity.inventory.items) do
		if i_item == item then
			inventory.unequip(entity, item.slot)

			table.remove(entity.inventory.items, i)
			if not inventory.get_selected(entity) then
				inventory.increment_selected_index(entity)
			end
			return
		end
	end
end

function inventory.get_with_name_where_not_full(entity, name)
	if not entity.inventory or not name then
		return nil
	end
	for _, i_item in ipairs(entity.inventory.items) do
		if
			i_item.name == name
			and i_item.charges
			and i_item.charges < (i_item.max_charges or game_cfg.inventory.max_stack_limit)
		then
			return i_item
		end
	end
	return nil
end

function inventory.get_first_with_field(entity, tag)
	if not entity.inventory or not tag then
		return nil
	end
	for _, i_item in ipairs(entity.inventory.items) do
		if i_item[tag] then
			return i_item
		end
	end
	return nil
end

function inventory.equip(entity, item)
	if not entity.inventory or not item.slot then
		return nil
	end

	local prev = entity.inventory.equipped[item.slot]
	entity.inventory.equipped[item.slot] = item
	return prev
end

function inventory.unequip(entity, slot)
	if not entity.inventory or not slot then
		return nil
	end
	local prev = entity.inventory.equipped[slot]
	entity.inventory.equipped[slot] = nil
	return prev
end

function inventory.is_equipped(entity, item)
	if not entity.inventory then
		return false
	end
	for _, equipped_item in pairs(entity.inventory.equipped) do
		if equipped_item and equipped_item == item then
			return true
		end
	end
	return false
end

function inventory.get_selected(entity)
	if not entity.inventory or not entity.inventory.selected_index then
		return nil
	end
	return entity.inventory.items[entity.inventory.selected_index]
end

function inventory.use_charge(item)
	if not item.charges then
		return false
	end
	item.charges = item.charges - 1
	return item.charges <= 0
end

function inventory.merge_stacks(item, count)
	if not item or not item.charges then
		return count
	end

	while count > 0 and item.charges < (item.max_charges or game_cfg.inventory.max_stack_limit) do
		count = count - 1
		item.charges = item.charges + 1
	end
	return count
end

function inventory.add_charge(item)
	if not item or not item.charges then
		return false
	end

	if item.max_charges and item.charges >= item.max_charges then
		return false
	end

	item.charges = item.charges + 1
	return true
end

function inventory.transfer(from, to, item)
	if not item then
		return false
	end
	inventory.add(to, item)

	inventory.remove(from, item)

	return true
end

return inventory
