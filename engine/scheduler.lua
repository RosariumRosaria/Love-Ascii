local utils = require("utils")

local scheduler = {}

local function get_speed(entity)
	local entities = require("entities.entities")
	return entities:get_stat(entity, "speed")
end

local queue = {}
local current_time = 0

local function convert_speed_to_turns(speed)
	return 100 / speed
end

function scheduler.peek()
	local head = queue[1]
	if not head then
		return nil
	end
	return head[1]
end

function scheduler.pop()
	local head = utils.priority_queue_get(queue)
	if not head then
		return nil
	end
	local entity = head[1]
	current_time = entity.next_turn
	return entity
end

function scheduler.schedule_turn(entity)
	if entity.dead then
		return
	end
	local turns = convert_speed_to_turns(get_speed(entity))
	entity.next_turn = current_time + turns
	utils.priority_queue_put(queue, entity, entity.next_turn)
end

return scheduler
