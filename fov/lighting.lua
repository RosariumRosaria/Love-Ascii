local shadowcaster = require("fov.shadowcaster")

local lighting = {}

local ex, ey, radius = 12, 14, 7
local debug_color = { r = 0.8, g = 0.6, b = 0.2 }

function lighting.cast_light(source_x, source_y, max_distance, color, intensity, max_x, max_y, tiles, lighting_grid)
	lighting_grid[source_y][source_x].r = math.min(lighting_grid[source_y][source_x].r + color.r * intensity, 1)
	lighting_grid[source_y][source_x].g = math.min(lighting_grid[source_y][source_x].g + color.g * intensity, 1)
	lighting_grid[source_y][source_x].b = math.min(lighting_grid[source_y][source_x].b + color.b * intensity, 1)

	shadowcaster.cast(source_x, source_y, max_distance, max_x, max_y, tiles, function(pos_x, pos_y, dx, dy, row, col, in_shadow)
		if in_shadow then
			return
		end
		local dist = math.sqrt(dx * dx + dy * dy)
		local falloff = math.max(0, 1 - dist / radius)
		local edge_factor = (col == 0 or col == row) and 0.5 or 1
		local contribution = falloff * intensity * edge_factor
		lighting_grid[pos_y][pos_x].r = math.min(lighting_grid[pos_y][pos_x].r + color.r * contribution, 1)
		lighting_grid[pos_y][pos_x].g = math.min(lighting_grid[pos_y][pos_x].g + color.g * contribution, 1)
		lighting_grid[pos_y][pos_x].b = math.min(lighting_grid[pos_y][pos_x].b + color.b * contribution, 1)
	end)
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
	lighting.cast_light(ex, ey, radius, debug_color, intensity, max_x, max_y, map_grid, lighting_grid)
end

return lighting
