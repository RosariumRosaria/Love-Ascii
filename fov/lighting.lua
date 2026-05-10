local shadow_line = require("fov.shadow_line")
local shadow = require("fov.shadow")
local utils = require("utils")
local entities = require("entities.entities")

local lighting = {}

local ex, ey, radius = 12, 14, 7
local debug_color = { r = 0.8, g = 0.6, b = 0.2 }

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

local function cast_light_octant(
	source_x,
	source_y,
	octant,
	max_distance,
	color,
	intensity,
	width,
	height,
	map_grid,
	lighting_grid
)
	local line = shadow_line:new()
	local full_shadow = false

	for row = 1, max_distance do
		local dx, dy = transform_octant(row, 0, octant)
		local pos_x = source_x + dx
		local pos_y = source_y + dy

		if not (utils.in_bounds(pos_x, pos_y, width, height)) then
			break
		end

		for col = 0, row do
			dx, dy = transform_octant(row, col, octant)
			pos_x = source_x + dx
			pos_y = source_y + dy

			if not (utils.in_bounds(pos_x, pos_y, width, height)) then
				break
			end

			if not utils.in_radius(dx, dy, max_distance) then
				break
			end

			if full_shadow then
				return false
			else
				local projection = shadow.project_tile(row, col)
				local is_in_shadow = line:is_in_shadow(projection)
				if not is_in_shadow then
					local dist = math.sqrt(dx * dx + dy * dy)
					local falloff = math.max(0, 1 - dist / radius)

					local edge_factor = (col == 0 or col == row) and 0.5 or 1
					local color_r = color.r * falloff * intensity * edge_factor
					local color_g = color.g * falloff * intensity * edge_factor
					local color_b = color.b * falloff * intensity * edge_factor
					lighting_grid[pos_y][pos_x].r = math.min(lighting_grid[pos_y][pos_x].r + color_r, 1)
					lighting_grid[pos_y][pos_x].g = math.min(lighting_grid[pos_y][pos_x].g + color_g, 1)
					lighting_grid[pos_y][pos_x].b = math.min(lighting_grid[pos_y][pos_x].b + color_b, 1)
				end

				local transparent = true
				if #map_grid[pos_y][pos_x] > 1 then
					transparent = map_grid[pos_y][pos_x][2].transparent
				end
				if not is_in_shadow and (not transparent or entities:get_tag_location(pos_x, pos_y, 1, "solid")) then
					line:add_shadow(projection)
					full_shadow = line:is_full_shadow()
				end
			end
		end
	end
end

function lighting:cast_light(source_x, source_y, max_distance, color, intensity, max_x, max_y, map_grid, lighting_grid)
	lighting_grid[source_y][source_x].r = math.min(lighting_grid[source_y][source_x].r + color.r * intensity, 1)
	lighting_grid[source_y][source_x].g = math.min(lighting_grid[source_y][source_x].g + color.g * intensity, 1)
	lighting_grid[source_y][source_x].b = math.min(lighting_grid[source_y][source_x].b + color.b * intensity, 1)

	for octant = 0, 7 do
		cast_light_octant(
			source_x,
			source_y,
			octant,
			max_distance,
			color,
			intensity,
			max_x,
			max_y,
			map_grid,
			lighting_grid
		)
	end
end

function lighting.recompute(max_x, max_y, map_grid, lighting_grid)
	for y = 1, max_y do
		for x = 1, max_x do
			lighting_grid[y][x].r = 0
			lighting_grid[y][x].g = 0
			lighting_grid[y][x].b = 0
		end
	end

	local intensity = 1
	lighting:cast_light(ex, ey, radius, debug_color, intensity, max_x, max_y, map_grid, lighting_grid)
end

return lighting
