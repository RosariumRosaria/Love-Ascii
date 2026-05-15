local shadowcaster = require("fov.shadowcaster")
local entities = require("entities.entities")
local lighting = {}

local function deposit(cell, color, contribution, flicker)
	cell.r = cell.r + color.r * contribution
	cell.g = cell.g + color.g * contribution
	cell.b = cell.b + color.b * contribution
	cell.sources[#cell.sources + 1] = { contribution = contribution, flicker = flicker }
end

function lighting.cast_light(source_x, source_y, light, max_x, max_y, tiles, lighting_grid)
	deposit(lighting_grid[source_y][source_x], light.color, light.intensity, light.flicker)

	shadowcaster.cast(
		source_x,
		source_y,
		light.radius,
		max_x,
		max_y,
		tiles,
		function(pos_x, pos_y, dx, dy, row, col, in_shadow)
			if in_shadow then
				return
			end
			local dist = math.sqrt(dx * dx + dy * dy)
			local falloff = math.max(0, 1 - dist / light.radius)
			local edge_factor = (col == 0 or col == row) and 0.5 or 1
			local contribution = falloff * light.intensity * edge_factor
			deposit(lighting_grid[pos_y][pos_x], light.color, contribution, light.flicker)
		end
	)
end

function lighting.recompute(max_x, max_y, map_grid, lighting_grid)
	for y = 1, max_y do
		for x = 1, max_x do
			local cell = lighting_grid[y][x]
			cell.r = 0
			cell.g = 0
			cell.b = 0
			local sources = cell.sources
			for i = #sources, 1, -1 do
				sources[i] = nil
			end
		end
	end

	for _, entity in ipairs(entities.entity_list) do
		if entity.light then
			lighting.cast_light(entity.x, entity.y, entity.light, max_x, max_y, map_grid, lighting_grid)
		end

		if entity.item and entity.item.light then
			lighting.cast_light(entity.x, entity.y, entity.item.light, max_x, max_y, map_grid, lighting_grid)
		end

		if entity.inventory and entity.inventory.equipped then
			for _, item in pairs(entity.inventory.equipped) do
				if item.light then
					lighting.cast_light(entity.x, entity.y, item.light, max_x, max_y, map_grid, lighting_grid)
				end
			end
		end
	end
end

return lighting
