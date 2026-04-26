local shadowLine = require("fov.shadow_line")
local shadow = require("fov.shadow")
local entities = require("entities.entities")
local fov_handler = {}

local function inbounds(x, y, width, height)
	return x >= 1 and x <= width and y >= 1 and y <= height
end

local function transformOctant(row, col, octant)
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

local function refreshOctant(
	entityX,
	entityY,
	octant,
	maxDistance,
	width,
	height,
	mapGrid,
	visibilityGrid,
	player,
	targetX,
	targetY
)
	local line = shadowLine:new()
	local fullShadow = false

	for row = 1, maxDistance do
		local dx, dy = transformOctant(row, 0, octant)
		local posX = entityX + dx
		local posY = entityY + dy

		if not (inbounds(posX, posY, width, height)) then
			break
		end

		for col = 0, row do
			dx, dy = transformOctant(row, col, octant)
			posX = entityX + dx
			posY = entityY + dy

			if not (inbounds(posX, posY, width, height)) then
				break
			end

			if fullShadow then
				if player then
					visibilityGrid[posY][posX] = false
				elseif posX == targetX and posY == targetY then
					return false
				end
			else
				local projection = shadow.projectTile(row, col)
				local visible = not line:isInShadow(projection)
				if player then
					visibilityGrid[posY][posX] = visible
				elseif posX == targetX and posY == targetY then
					return visible
				end

				local transparent = true
				if #mapGrid[posY][posX] > 1 then
					transparent = mapGrid[posY][posX][2].transparent
				end
				if visible and (not transparent or entities:get_tag_location(posX, posY, 1, "solid")) then
					line:AddShadow(projection)
					fullShadow = line:isFullShadow()
				end
			end
		end
	end
end

function fov_handler.refreshVisibility(
	entityX,
	entityY,
	maxDistance,
	width,
	height,
	mapGrid,
	visibilityGrid,
	player,
	targetX,
	targetY
)
	if player then
		visibilityGrid[entityY][entityX] = true
	end
	for octant = 0, 7 do
		local visible = refreshOctant(
			entityX,
			entityY,
			octant,
			maxDistance,
			width,
			height,
			mapGrid,
			visibilityGrid,
			player,
			targetX,
			targetY
		) --TODO check if this works really for enemies
		if visible then
			return true
		end
	end
	return false
end

return fov_handler
