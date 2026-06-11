local shadowcaster = require("fov.shadowcaster")

local fov_handler = {}

function fov_handler.refresh(
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

	local result = shadowcaster.cast(
		entity_x,
		entity_y,
		max_distance,
		width,
		height,
		map_grid,
		function(pos_x, pos_y, dx, dy, row, col, in_shadow)
			if is_player then
				visibility_grid[pos_y][pos_x] = not in_shadow
			elseif pos_x == target_x and pos_y == target_y then
				return not in_shadow
			end
		end
	)

	return result or false
end

return fov_handler
