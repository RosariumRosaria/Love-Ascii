local entities = require("src.sim.entities")

local cursor = {}
local moused_ids = nil
local moused_entity_i = 1
local moused_x = nil
local moused_y = nil
local sel_x, sel_y = nil, nil
local flagged_id = nil

function cursor.reset()
	moused_ids = nil
	moused_entity_i = 1
	moused_x = nil
	moused_y = nil
	sel_x, sel_y = nil, nil
	flagged_id = nil
end

function cursor.set_moused_coords(x, y)
	moused_x = x
	moused_y = y
end

function cursor.get_moused_coords()
	return moused_x, moused_y
end

local function apply_moused_selection()
	local new = cursor.get_moused_entity()
	local new_id = new and new.id or nil
	if new_id ~= flagged_id then
		local flagged = flagged_id and entities.get_by_id(flagged_id)
		if flagged then
			flagged.moused = false
		end
		if new then
			new.moused = true
		end
		flagged_id = new_id
		return true
	end
	return false
end

function cursor.set_moused_entity(entity_list)
	if moused_x ~= sel_x or moused_y ~= sel_y then
		sel_x, sel_y = moused_x, moused_y
		moused_entity_i = 1
	end

	if entity_list and #entity_list > 0 then
		moused_ids = {}
		for i = 1, #entity_list do
			moused_ids[i] = entity_list[i].id
		end
	else
		moused_ids = nil
	end

	moused_entity_i = math.min(moused_entity_i, (moused_ids and #moused_ids) or 1)
	return apply_moused_selection()
end

function cursor.scroll_entity(delta)
	local n = moused_ids and #moused_ids or 0
	if n <= 1 then
		return false
	end
	moused_entity_i = (moused_entity_i - 1 + delta) % n + 1
	return apply_moused_selection()
end

function cursor.get_moused_entity()
	local id = moused_ids and moused_ids[moused_entity_i]
	return id and entities.get_by_id(id) or nil
end

return cursor
