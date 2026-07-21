--NOTE Recursive shadowcasting walker shared by fov.visibility and fov.lighting.
--     Algorithm: https://journal.stuffwithstuff.com/2015/09/07/what-the-hero-sees/

local shadow_line = require("fov.shadow_line")
local shadow = require("fov.shadow")
local entities = require("entities.entities")
local utils = require("utils")

local shadowcaster = {}

local function transform_octant(row, col, octant)
	local dx, dy
	if octant == 0 then
		dx, dy = col, -row
	elseif octant == 1 then
		dx, dy = row, -col
	elseif octant == 2 then
		dx, dy = row, col
	elseif octant == 3 then
		dx, dy = col, row
	elseif octant == 4 then
		dx, dy = -col, row
	elseif octant == 5 then
		dx, dy = -row, col
	elseif octant == 6 then
		dx, dy = -row, -col
	elseif octant == 7 then
		dx, dy = -col, -row
	else
		error("Invalid octant: " .. tostring(octant))
	end
	return dx, dy
end

local function is_blocker(tiles, pos_x, pos_y)
	local transparent = true
	if #tiles[pos_y][pos_x] > 1 then
		transparent = tiles[pos_y][pos_x][2].transparent
	end
	return not transparent or entities.get_tag_location(pos_x, pos_y, 1, "solid")
end

local function cast_octant(origin_x, origin_y, octant, max_distance, max_x, max_y, tiles, on_visit)
	local line = shadow_line:new()
	local full_shadow = false

	for row = 1, max_distance do
		local dx, dy = transform_octant(row, 0, octant)
		local pos_x = origin_x + dx
		local pos_y = origin_y + dy

		if not utils.in_bounds(pos_x, pos_y, max_x, max_y) then
			break
		end

		for col = 0, row do
			dx, dy = transform_octant(row, col, octant)
			pos_x = origin_x + dx
			pos_y = origin_y + dy

			if not utils.in_bounds(pos_x, pos_y, max_x, max_y) then
				break
			end

			if not utils.in_radius(dx, dy, max_distance) then
				break
			end

			if full_shadow then
				local result = on_visit(pos_x, pos_y, dx, dy, row, col, true)
				if result ~= nil then
					return result
				end
			else
				local projection = shadow.project_tile(row, col)
				local in_shadow = line:is_in_shadow(projection)

				local result = on_visit(pos_x, pos_y, dx, dy, row, col, in_shadow)
				if result ~= nil then
					return result
				end

				if not in_shadow and is_blocker(tiles, pos_x, pos_y) then
					line:add_shadow(projection)
					full_shadow = line:is_full_shadow()
				end
			end
		end
	end
end

function shadowcaster.cast(origin_x, origin_y, max_distance, max_x, max_y, tiles, on_visit)
	for octant = 0, 7 do
		local result = cast_octant(origin_x, origin_y, octant, max_distance, max_x, max_y, tiles, on_visit)
		if result ~= nil then
			return result
		end
	end
end

return shadowcaster
