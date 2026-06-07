local utils = require("utils")
local stats = require("stats.stats")
local game_cfg = require("config.game_config")
local event_log = require("engine.event_log")
local time = {}

local function get_speed(entity)
	return stats.get_stat(entity, "speed")
end

local queue = {}
local current_time = 0

local function convert_speed_to_turns(speed)
	return 100 / speed
end

function time.peek()
	local head = queue[1]
	if not head then
		return nil
	end
	return head[1]
end

function time.pop()
	local head = utils.priority_queue_get(queue)
	if not head then
		return nil
	end
	local entity = head[1]
	current_time = entity.next_turn
	return entity
end

function time.time_of_day()
	return (current_time % game_cfg.timing.day_length) / game_cfg.timing.day_length
end

function time.part_of_day()
	local t = time.time_of_day()

	local keyframes = game_cfg.timing.time_keyframes
	local name = keyframes[1][1]
	for i = 1, #keyframes do
		if t >= keyframes[i].at then
			name = keyframes[i][1]
		else
			break
		end
	end
	return name
end

function time.schedule_turn(entity)
	if entity.dead then
		return
	end
	local turns = convert_speed_to_turns(get_speed(entity))
	entity.next_turn = current_time + turns
	utils.priority_queue_put(queue, entity, entity.next_turn)
end

return time
