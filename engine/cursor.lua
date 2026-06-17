local cursor = {}
local moused_entity_list = nil
local moused_entity_i = 1 --TODO, should not be a magic number, should be scrollable
local moused_x = nil
local moused_y = nil
local sel_x, sel_y = nil, nil

function cursor.set_moused_coords(x, y)
	moused_x = x
	moused_y = y
end

function cursor.get_moused_coords()
	return moused_x, moused_y
end

function cursor.set_moused_entity(entity_list)
	if moused_x == sel_x and moused_y == sel_y then
		moused_entity_list = entity_list -- same cell: refresh live ref, keep i + flag
		return false
	end

	local old = cursor.get_moused_entity()
	if old then
		old.moused = false
	end
	sel_x, sel_y = moused_x, moused_y
	moused_entity_i = 1
	if entity_list and #entity_list > 0 then
		moused_entity_list = entity_list
		entity_list[1].moused = true
		return true
	else
		moused_entity_list = nil
		return false
	end
end
function cursor.get_moused_entity()
	if moused_entity_list and moused_entity_list[moused_entity_i] then
		return moused_entity_list[moused_entity_i]
	end
	return nil
end

return cursor
