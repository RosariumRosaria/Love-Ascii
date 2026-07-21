local item_types = require("src.sim.item_types")
local utils = require("src.utils")

local game_cfg = require("src.config.game_config")

local inventory = {}
local inventory_template = {
	items = {},
	equipped = { armor = nil, offhand = nil, accessory = nil, mainhand = nil },
	selected_index = nil,
}

function inventory.get_equipped(entity, slot)
	if not entity or not entity.inventory or not slot then
		return nil
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

function inventory.check_index(entity, index)
	if not entity.inventory then
		return false
	end
	return index > 0 and #entity.inventory.items >= index
end

function inventory.set_selected_index(entity, index)
	if not inventory.check_index(entity, index) then
		return false
	end
	entity.inventory.selected_index = index
	return true
end

function inventory.add(entity, item)
	if not entity.inventory then
		entity.inventory = utils.deep_copy(inventory_template)
	end
	if utils.get_tag(item, "stacks") and item.charges then
		if item.charges <= 0 then
			return nil
		end

		local cap = item.max_charges or game_cfg.inventory.max_stack_limit
		local stored = nil
		local existing_item = inventory.get_with_name_where_not_full(entity, item.name)
		while existing_item and item.charges > 0 do
			item.charges = inventory.merge_stacks(existing_item, item.charges)
			stored = stored or existing_item
			existing_item = inventory.get_with_name_where_not_full(entity, item.name)
		end
		while item.charges > cap do
			local overflow = utils.deep_copy(item)
			overflow.charges = cap
			table.insert(entity.inventory.items, overflow)
			stored = stored or overflow
			item.charges = item.charges - cap
		end

		if item.charges > 0 then
			table.insert(entity.inventory.items, item)
			stored = stored or item
		end

		return stored
	end

	table.insert(entity.inventory.items, item)
	return item
end

local CONTEXTUAL_STATS = { damage = true }
local WEAPON_SLOTS = { mainhand = true, offhand = true }

local function stamp_modifier_contexts(item)
	if not item.modifiers then
		return
	end

	local original = item.modifiers
	local implied
	if item.ranged or item.slot == "ammo" then
		implied = "ranged"
	elseif WEAPON_SLOTS[item.slot] then
		implied = "melee"
	else
		return
	end

	for i, mod in ipairs(item.modifiers) do
		if not mod.context and CONTEXTUAL_STATS[mod.stat] then
			if item.modifiers == original then
				item.modifiers = utils.deep_copy(original)
			end
			item.modifiers[i].context = implied
		end
	end
end

function inventory.create_from_template(name, overrides)
	local new_item = utils.create_instance_from_template(item_types, name, overrides)
	utils.randomize_flicker(new_item.light)
	stamp_modifier_contexts(new_item)
	return new_item
end

function inventory.add_from_template(entity, name, overrides)
	local new_item = inventory.create_from_template(name, overrides)
	return inventory.add(entity, new_item)
end

function inventory.remove(entity, item)
	if not entity.inventory then
		return
	end
	for i, i_item in ipairs(entity.inventory.items) do
		if i_item == item then
			if inventory.is_equipped(entity, item) then
				inventory.unequip(entity, item.slot)
			end

			table.remove(entity.inventory.items, i)
			inventory.fixup_selected_index(entity, i)
			return
		end
	end
end

function inventory.fixup_selected_index(entity, removed_index)
	local inv = entity.inventory
	if not inv or not inv.selected_index then
		return
	end

	if #inv.items == 0 then
		inv.selected_index = nil
	elseif inv.selected_index > removed_index then
		inv.selected_index = inv.selected_index - 1
	elseif inv.selected_index > #inv.items then
		inv.selected_index = 1
	end
end

local function find_item(entity, predicate, arg)
	if not entity.inventory then
		return nil
	end
	for _, i_item in ipairs(entity.inventory.items) do
		if predicate(i_item, arg) then
			return i_item
		end
	end
	return nil
end

local function stack_of_name_with_room(item, name)
	return item.name == name
		and item.charges
		and item.charges < (item.max_charges or game_cfg.inventory.max_stack_limit)
end

local function has_field(item, field)
	return item[field]
end

local function is_usable_ammo(item)
	return item.slot == "ammo" and (item.charges or 0) > 0
end

function inventory.get_with_name_where_not_full(entity, name)
	if not name then
		return nil
	end
	return find_item(entity, stack_of_name_with_room, name)
end

function inventory.get_first_with_field(entity, field)
	if not field then
		return nil
	end
	return find_item(entity, has_field, field)
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

function inventory.use_charge(entity, item)
	if not item.charges or item.charges <= 0 then
		return false
	end
	item.charges = item.charges - 1
	if item.charges <= 0 and utils.get_tag(item, "consumable") then
		inventory.remove(entity, item)
	end
	return item.charges <= 0
end

function inventory.get_ammo(entity)
	local ammo = inventory.get_equipped(entity, "ammo")
	if ammo and (ammo.charges or 0) > 0 then
		return ammo
	end
	return find_item(entity, is_usable_ammo)
end

function inventory.equip_ammo(entity, item)
	if not utils.get_tag(item, "requires_ammo") then
		return nil
	end
	local ammo = inventory.get_ammo(entity)
	if not ammo then
		return nil
	end
	if inventory.get_equipped(entity, "ammo") ~= ammo then
		inventory.equip(entity, ammo)
	end
	return ammo
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
