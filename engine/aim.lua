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

local function move_to(x, y)
	aim.x = x
	aim.y = y
	aim.reticle.x = x
	aim.reticle.y = y
end

function aim.find_targets_in_range(actor) -- TODO: Some of this code should definitely live in map, I can see this being useful for enemy ai too.
	local targets = {}
	for _, entity in ipairs(entities.get_list()) do
		if
			entity.team
			and entity.team ~= actor.team
			and not entity.dead
			and entity ~= actor
			and map:is_visible(entity.x, entity.y)
		then
			local distance = utils.distance_between(actor, entity)

			if distance <= aim.range then
				table.insert(targets, {
					entity = entity,
					distance = distance,
				})
			end
		end
	end

	table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)

	if #targets > 0 then
		return targets
	end

	return nil
end

function aim.cycle_target()
	if aim.targets and #aim.targets > 0 then
		local target = aim.targets[aim.nth].entity
		aim.current_target = target
		move_to(target.x, target.y)
		aim.nth = (aim.nth % #aim.targets) + 1
	end
end

function aim.refresh()
	aim.targets = aim.find_targets_in_range(aim.entity)

	if aim.current_target and aim.targets then
		for i, t in ipairs(aim.targets) do
			if t.entity == aim.current_target then
				move_to(t.entity.x, t.entity.y)
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
	aim.targets = aim.find_targets_in_range(entity)
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
	local tar_x = aim.x + dx
	local tar_y = aim.y + dy
	if
		map:in_bounds(tar_x, tar_y)
		and map:is_visible(tar_x, tar_y)
		and utils.distance_between_coords(tar_x, tar_y, aim.origin_x, aim.origin_y) <= aim.range
	then
		aim.current_target = nil
		move_to(tar_x, tar_y)
	end
end

return aim
