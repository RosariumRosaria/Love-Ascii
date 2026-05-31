local shadowcaster = require("fov.shadowcaster")
local entities = require("entities.entities")
local lighting = {}

local prev_lit = {}

local function deposit(cell, color, contribution, flicker, source_z)
	cell.r = cell.r + color.r * contribution
	cell.g = cell.g + color.g * contribution
	cell.b = cell.b + color.b * contribution
	cell.sources[#cell.sources + 1] = { contribution = contribution, flicker = flicker, z = source_z }
	prev_lit[#prev_lit + 1] = cell
end

function lighting.cast_light(source_x, source_y, source_z, light, max_x, max_y, tiles, lighting_grid)
	deposit(lighting_grid[source_y][source_x], light.color, light.intensity, light.flicker, source_z)

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
			deposit(lighting_grid[pos_y][pos_x], light.color, contribution, light.flicker, source_z)
		end
	)
end

local function in_range(ex, ey, cx, cy, view_radius, light)
	local reach = view_radius + light.radius
	return math.abs(ex - cx) <= reach and math.abs(ey - cy) <= reach
end

function lighting.recompute(max_x, max_y, map_grid, lighting_grid, center_x, center_y, view_radius)
	for _, cell in ipairs(prev_lit) do
		cell.r, cell.g, cell.b = 0, 0, 0
		local sources = cell.sources
		for i = #sources, 1, -1 do
			sources[i] = nil
		end
	end

	prev_lit = {}

	for _, entity in ipairs(entities.entity_list) do
		local ex, ey = entity.x, entity.y

		if entity.light and in_range(ex, ey, center_x, center_y, view_radius, entity.light) then
			lighting.cast_light(ex, ey, entity.z, entity.light, max_x, max_y, map_grid, lighting_grid)
		end

		if
			entity.item
			and entity.item.light
			and in_range(ex, ey, center_x, center_y, view_radius, entity.item.light)
		then
			lighting.cast_light(ex, ey, entity.z, entity.item.light, max_x, max_y, map_grid, lighting_grid)
		end

		if entity.inventory and entity.inventory.equipped then
			for _, item in pairs(entity.inventory.equipped) do
				if item.light and in_range(ex, ey, center_x, center_y, view_radius, item.light) then
					lighting.cast_light(ex, ey, entity.z, item.light, max_x, max_y, map_grid, lighting_grid)
				end
			end
		end
	end
end

return lighting
