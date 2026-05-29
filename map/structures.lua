local structure_types = require("map.structure_types")
local tile_types = require("map.tile_types")

local structures = {}

-- Fill a vertical column at (x, y) from base_z to top_z (inclusive) with tile.
function structures.fill_column(tiles, x, y, base_z, top_z, tile)
	for z = base_z, top_z do
		tiles[y][x][z] = tile
	end
end

-- Roll a random total height for a named structure, clamped so the top never
-- exceeds max_z. Returns 0 if the structure doesn't fit or doesn't exist.
function structures.roll_height(name, max_z)
	local template = structure_types[name]
	if not template then
		return 0
	end
	local base_z = template.base_z or 1
	local height = math.random(template.min_height, template.max_height)
	return math.max(0, math.min(height, max_z - base_z + 1))
end

-- Stamp a point structure. Assumes (x, y) is in bounds; clamps so the top
-- never exceeds max_z. With a cap, fill spans base..top-1 and the cap sits on
-- top; without a cap, fill spans the whole column.
function structures.place(name, x, y, tiles, max_z)
	local template = structure_types[name]
	if not template then
		return
	end

	local base_z = template.base_z or 1
	local height = structures.roll_height(name, max_z)
	if height < 1 then
		return
	end

	local top_z = base_z + height - 1
	local fill = tile_types[template.fill]
	local cap = tile_types[template.cap]

	if fill then
		structures.fill_column(tiles, x, y, base_z, cap and top_z - 1 or top_z, fill)
	end
	if cap then
		tiles[y][x][top_z] = cap
	end
end

return structures
