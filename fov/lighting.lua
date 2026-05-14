local shadowcaster = require("fov.shadowcaster")
local entities = require("entities.entities")
local lighting = {}

local function deposit(cell, color, contribution, flicker)
	cell.r = cell.r + color.r * contribution
	cell.g = cell.g + color.g * contribution
	cell.b = cell.b + color.b * contribution

	if contribution > (cell.dominant or 0) then
		cell.dominant = contribution
		cell.flicker = flicker
	end
end

function lighting.cast_light(source_x, source_y, radius, color, intensity, max_x, max_y, tiles, flicker, lighting_grid)
	deposit(lighting_grid[source_y][source_x], color, intensity)

	shadowcaster.cast(
		source_x,
		source_y,
		radius,
		max_x,
		max_y,
		tiles,
		function(pos_x, pos_y, dx, dy, row, col, in_shadow)
			if in_shadow then
				return
			end
			local dist = math.sqrt(dx * dx + dy * dy)
			local falloff = math.max(0, 1 - dist / radius)
			local edge_factor = (col == 0 or col == row) and 0.5 or 1
			local contribution = falloff * intensity * edge_factor
			deposit(lighting_grid[pos_y][pos_x], color, contribution, flicker)
		end
	)
end

function lighting.recompute(max_x, max_y, map_grid, lighting_grid)
	for y = 1, max_y do
		for x = 1, max_x do
			lighting_grid[y][x].r = 0
			lighting_grid[y][x].g = 0
			lighting_grid[y][x].b = 0
		end
	end

	for _, entity in ipairs(entities.entity_list) do
		if entity.light then
			lighting.cast_light(
				entity.x,
				entity.y,
				entity.light.radius,
				entity.light.color,
				entity.light.intensity,
				max_x,
				max_y,
				map_grid,
				entity.light.flicker,
				lighting_grid
			)
		end

		if entity.inventory and entity.inventory.equipped then
			for _, item in pairs(entity.inventory.equipped) do
				if item.light then
					lighting.cast_light(
						entity.x,
						entity.y,
						item.light.radius, --TODO Refactor to use lighting table
						item.light.color,
						item.light.intensity,
						max_x,
						max_y,
						map_grid,
						item.light.flicker,
						lighting_grid
					)
				end
			end
		end
	end
end

return lighting
