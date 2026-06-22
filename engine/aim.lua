local effects = require("visuals.effects.effects")
local map = require("map.map")
local inventory = require("items.inventory")
local utils = require("utils")
local entities = require("entities.entities")

local aim = {
	active = false,
	x = nil,
	y = nil,
	origin_x = nil,
	origin_y = nil,
	reticle = nil,
	range = nil,
	nth = nil,
	entity = nil,
	current_target = nil,
}

function aim.move_to(x, y)
	if
		map:in_bounds(x, y)
		and map:is_visible(x, y)
		and utils.distance_between_coords(x, y, aim.origin_x, aim.origin_y) <= aim.range
	then
		aim.x = x
		aim.y = y
		aim.reticle.x = x
		aim.reticle.y = y
	end
end

function aim.find_targets_in_range()
	local targets = map:find_targets_in_range(aim.entity, aim.range)
	if not targets then
		return
	end

	for i = #targets, 1, -1 do
		local pair = targets[i]

		if not map:is_visible(pair.entity.x, pair.entity.y) then
			table.remove(targets, i)
		end
	end

	if #targets > 0 then
		return targets
	end

	return nil
end

function aim.cycle_target()
	if aim.targets and #aim.targets > 0 then
		local target = aim.targets[aim.nth].entity
		aim.current_target = target
		aim.move_to(target.x, target.y)
		aim.nth = (aim.nth % #aim.targets) + 1
	end
end

function aim.refresh()
	aim.targets = aim.find_targets_in_range()

	if aim.current_target and aim.targets then
		for i, t in ipairs(aim.targets) do
			if t.entity == aim.current_target then
				aim.move_to(t.entity.x, t.entity.y)
				aim.nth = (i % #aim.targets) + 1
				return
			end
		end
	end

	aim.current_target = nil
	aim.nth = 1
	aim.cycle_target()
end

function aim.enter(entity, x, y)
	aim.active = true
	aim.entity = entity
	aim.weapon = inventory.get_equipped(entity, "mainhand")
	aim.range = aim.weapon.range
	aim.x = x
	aim.origin_x = x
	aim.y = y
	aim.origin_y = y
	aim.reticle = effects:add_from_template("reticle", aim.x, aim.y, entity.z)
	aim.nth = 1
	aim.targets = aim.find_targets_in_range()
	aim.cycle_target()
end

function aim.exit()
	aim.active = false
	effects:remove_effect(aim.reticle)
	aim.x, aim.y = nil, nil
	aim.origin_x, aim.origin_y = nil, nil
	aim.reticle = nil
	aim.range = nil
	aim.weapon = nil
	aim.targets = nil
	aim.nth = nil
	aim.entity = nil
	aim.current_target = nil
end

function aim.move(dx, dy)
	aim.current_target = nil
	aim.move_to(aim.x + dx, aim.y + dy)
end

return aim
