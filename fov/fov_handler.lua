--NOTE Based off of https://journal.stuffwithstuff.com/2015/09/07/what-the-hero-sees/

local shadow_line = require("fov.shadow_line")
local shadow = require("fov.shadow")
local entities = require("entities.entities")
local utils = require("utils")
local fov_handler = {}

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

local function refresh_octant(
	entity_x,
	entity_y,
	octant,
	max_distance,
	width,
	height,
	map_grid,
	visibility_grid,
	player,
	target_x,
	target_y
)
	local line = shadow_line:new()
	local full_shadow = false

	for row = 1, max_distance do
		local dx, dy = transform_octant(row, 0, octant)
		local pos_x = entity_x + dx
		local pos_y = entity_y + dy

		if not (utils.in_bounds(pos_x, pos_y, width, height)) then
			break
		end

		for col = 0, row do
			dx, dy = transform_octant(row, col, octant)
			pos_x = entity_x + dx
			pos_y = entity_y + dy

			if not (utils.in_bounds(pos_x, pos_y, width, height)) then
				break
			end

			if full_shadow then
				if player then
					visibility_grid[pos_y][pos_x] = false
				elseif pos_x == target_x and pos_y == target_y then
					return false
				end
			else
				local projection = shadow.project_tile(row, col)
				local visible = not line:is_in_shadow(projection)
				if player then
					visibility_grid[pos_y][pos_x] = visible
				elseif pos_x == target_x and pos_y == target_y then
					return visible
				end

				local transparent = true
				if #map_grid[pos_y][pos_x] > 1 then
					transparent = map_grid[pos_y][pos_x][2].transparent
				end
				if visible and (not transparent or entities:get_tag_location(pos_x, pos_y, 1, "solid")) then
					line:add_shadow(projection)
					full_shadow = line:is_full_shadow()
				end
			end
		end
	end
end

function fov_handler.refresh_visibility(
	entity_x,
	entity_y,
	max_distance,
	width,
	height,
	map_grid,
	visibility_grid,
	is_player,
	target_x,
	target_y
)
	if is_player then
		visibility_grid[entity_y][entity_x] = true
	end
	for octant = 0, 7 do
		local visible = refresh_octant(
			entity_x,
			entity_y,
			octant,
			max_distance,
			width,
			height,
			map_grid,
			visibility_grid,
			is_player,
			target_x,
			target_y
		) --TODO check if this works really for enemies
		if visible then
			return true
		end
	end
	return false
end

return fov_handler
