local debug_state = require("src.debug.debug_state")

-- Warnings about what town generation actually produced. Nothing here feeds the game;
-- it reads the generator's scratch data and prints to the launching terminal.
local generation_report = {}

local FLOOD_OFFSETS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- `mask` is a building's room mask from features.make_building: 0 outside, -1 wall band,
-- >0 a room id, with a border ring at 0/w+1 so neighbour lookups never fall off. Flood
-- from one room through every doorway and shout about any room the fill never reaches.
-- `doorways` are world positions; ox,oy translate them back into mask space.
function generation_report.check_sealed_rooms(mask, width, height, doorways, ox, oy)
	if not debug_state.log_generation then
		return
	end

	local stride = width + 2
	local open, present = {}, {}
	for _, doorway in ipairs(doorways) do
		open[(doorway.y - oy) * stride + (doorway.x - ox)] = true
	end

	local start_x, start_y
	for y = 1, height do
		for x = 1, width do
			local id = mask[y][x]
			if id > 0 then
				present[id] = true
				start_x = start_x or x
				start_y = start_y or y
			end
		end
	end
	if not start_x then
		return
	end

	local seen = { [start_y * stride + start_x] = true }
	local reached = { [mask[start_y][start_x]] = true }
	local frontier = { { start_x, start_y } }
	while #frontier > 0 do
		local cell = table.remove(frontier)
		for _, offset in ipairs(FLOOD_OFFSETS) do
			local nx, ny = cell[1] + offset[1], cell[2] + offset[2]
			if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
				local key = ny * stride + nx
				local id = mask[ny][nx]
				if not seen[key] and (id > 0 or open[key]) then
					seen[key] = true
					if id > 0 then
						reached[id] = true
					end
					frontier[#frontier + 1] = { nx, ny }
				end
			end
		end
	end

	local sealed = {}
	for id in pairs(present) do
		if not reached[id] then
			sealed[#sealed + 1] = id
		end
	end
	if #sealed > 0 then
		table.sort(sealed)
		print(
			("features.make_building: %d sealed room(s) [%s] in building at %d,%d"):format(
				#sealed,
				table.concat(sealed, ", "),
				ox + 1,
				oy + 1
			)
		)
	end
end

return generation_report
