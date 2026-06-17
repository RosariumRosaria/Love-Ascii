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

local flagged = nil
function cursor.set_moused_entity(entity_list)
	if moused_x ~= sel_x or moused_y ~= sel_y then
		sel_x, sel_y = moused_x, moused_y
		moused_entity_i = 1
	end
	moused_entity_list = (entity_list and #entity_list > 0) and entity_list or nil
	moused_entity_i = math.min(moused_entity_i, (moused_entity_list and #moused_entity_list) or 1)
	local new = cursor.get_moused_entity()
	if new ~= flagged then
		if flagged then
			flagged.moused = false
		end
		if new then
			new.moused = true
		end
		flagged = new
		return true
	end
	return false
end

function cursor.get_moused_entity()
	if moused_entity_list and moused_entity_list[moused_entity_i] then
		return moused_entity_list[moused_entity_i]
	end
	return nil
end

return cursor
