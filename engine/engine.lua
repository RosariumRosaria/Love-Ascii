local entities = require("entities.entities")
local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local engine_utils = require("engine.engine_utils")

local engine = {}

local function validate_interaction(actor, target, name)
	if not actor then
		ui_handler:add_text_to_ui_by_name("terminal", name .. " actor is nil")
		return false
	end
	if not target then
		ui_handler:add_text_to_ui_by_name("terminal", name .. " target is nil")
		return false
	end
	if engine_utils.distance_between(actor, target) > 1 then
		ui_handler:add_text_to_ui_by_name("terminal", name .. " too far apart")
		return false
	end
	return true
end

function engine:default_interact(entity, dx, dy)
	local target = entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not target then
		return false
	end
	local action = target.default_action
	if action == "interactable" and entity.allowed_actions[action] then
		return self:interact(entity, dx, dy)
	elseif action == "attackable" and entity.allowed_actions[action] then
		return self:attack(entity, dx, dy)
	elseif action == "moveable" and entity.allowed_actions[action] then
		return self:push(entity, dx, dy)
	end
	return false
end

function engine:attack(entity, dx, dy)
	local target_entity = entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not validate_interaction(entity, target_entity, "Attack") then
		return false
	end
	if not entities:get_tag_entity(target_entity, "attackable") then
		ui_handler:add_text_to_ui_by_name("terminal", target_entity.name .. " is not attackable")
		return false
	end
	if entity.type ~= target_entity.type then
		visuals:add_from_template("attack", entity.x + dx, entity.y + dy, entity.z)
		entities:damage_entity(target_entity, entity)
	end
	return true
end

function engine:interact(entity, dx, dy)
	local target_entity = entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not validate_interaction(entity, target_entity, "Interact") then
		return false
	end

	if not target_entity.tags.interactable then
		ui_handler:add_text_to_ui_by_name("terminal", "Nothing to do here")
		return false
	end
	entities:interact_with_entity(target_entity)
	return true
end

function engine:inspect(entity, dx, dy)
	local target_entity = entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not validate_interaction(entity, target_entity, "Inspect") then
		return false
	end

	entities:inspect_entity(target_entity)
end

function engine:move(entity, dx, dy)
	local tar_x = entity.x + dx
	local tar_y = entity.y + dy

	if engine_utils.is_tile_free(tar_x, tar_y, entity.z, { [entity] = true }) then
		local visual = visuals:add_from_template("trail", entity.x, entity.y, entity.z)
		visual.rects[1].colors[1] = entity.effect_color or visual.rects[1].colors[1]
		entity.x = tar_x
		entity.y = tar_y
		return true
	end

	return engine:default_interact(entity, dx, dy)
end

function engine:grab(entity, dx, dy)
	return entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
end

function engine:push(entity, dx, dy) --TODO Probably some way to integrate pushing and pulling, and to use move
	local target_entity = entities:get_entity(entity.x + dx, entity.y + dy, entity.z)
	if not validate_interaction(entity, target_entity, "Push") then
		return false
	end

	if not target_entity.tags.moveable then
		return false
	end

	local pusher_tar_x = entity.x + dx
	local pusher_tar_y = entity.y + dy
	local pushed_tar_x = target_entity.x + dx
	local pushed_tar_y = target_entity.y + dy
	if
		not engine_utils.is_tile_free(pusher_tar_x, pusher_tar_y, entity.z, { [entity] = true, [target_entity] = true })
	then
		ui_handler:add_text_to_ui_by_name("terminal", "Pusher tile not free")
		return false
	end
	if not engine_utils.is_tile_free(pushed_tar_x, pushed_tar_y, target_entity.z, { [target_entity] = true }) then
		ui_handler:add_text_to_ui_by_name("terminal", "Pushed tile not free")
		return false
	end
	visuals:add_from_template("trail", entity.x, entity.y, entity.z)
	entity.x = pusher_tar_x
	entity.y = pusher_tar_y
	target_entity.x = pushed_tar_x
	target_entity.y = pushed_tar_y
	ui_handler:add_text_to_ui_by_name(
		"terminal",
		"Pushed " .. target_entity.name .. " to " .. pushed_tar_x .. ", " .. pushed_tar_y
	)

	return true
end

function engine:pull(entity, dx, dy)
	local target_entity = entities:get_entity(entity.x - dx, entity.y - dy, entity.z)
	if not validate_interaction(entity, target_entity, "Pull") then
		return false
	end

	if not target_entity.tags.moveable then
		return false
	end
	local puller_tar_x = entity.x + dx
	local puller_tar_y = entity.y + dy
	local pulled_tar_x = target_entity.x + dx
	local pulled_tar_y = target_entity.y + dy

	if not engine_utils.is_tile_free(puller_tar_x, puller_tar_y, entity.z, { [entity] = true }) then
		ui_handler:add_text_to_ui_by_name("terminal", "Puller tile not free")
		return false
	end

	if
		not engine_utils.is_tile_free(
			pulled_tar_x,
			pulled_tar_y,
			target_entity.z,
			{ [entity] = true, [target_entity] = true }
		)
	then
		ui_handler:add_text_to_ui_by_name("terminal", "Pulled tile not free")
		return false
	end
	visuals:add_from_template("trail", entity.x, entity.y, entity.z)
	entity.x = puller_tar_x
	entity.y = puller_tar_y
	target_entity.x = pulled_tar_x
	target_entity.y = pulled_tar_y
	ui_handler:add_text_to_ui_by_name(
		"terminal",
		"Pulled " .. target_entity.name .. " to " .. pulled_tar_x .. ", " .. pulled_tar_y
	)

	return true
end

return engine
