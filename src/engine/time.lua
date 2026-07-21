local utils = require("src.utils")
local stats = require("src.sim.stats")
local game_cfg = require("src.config.game_config")
local render_config = require("src.config.render_config")
local event_log = require("src.engine.event_log")
local time = {}

local ambient_cache = { r = 0, g = 0, b = 0 }
local ambient_cache_t = nil

local function get_speed(entity)
	return stats.get(entity, "speed")
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

function time.ambient_color()
	local t = time.time_of_day()
	if t == ambient_cache_t then
		return ambient_cache
	end

	local keys = render_config.lighting.ambient_keys
	local A, B
	for i = 1, #keys do
		if keys[i].at <= t then
			A, B = keys[i], keys[i + 1]
		else
			break
		end
	end
	local span, f
	if B then
		span = B.at - A.at
	else
		B, span = keys[1], (keys[1].at + 1.0) - A.at
	end
	f = span > 0 and (t - A.at) / span or 0

	ambient_cache.r = utils.lerp(A.color.r, B.color.r, f)
	ambient_cache.g = utils.lerp(A.color.g, B.color.g, f)
	ambient_cache.b = utils.lerp(A.color.b, B.color.b, f)
	ambient_cache_t = t
	return ambient_cache
end

function time.schedule_turn(entity, cost)
	if entity.dead then
		return
	end
	local turns = convert_speed_to_turns(get_speed(entity)) * (cost or 1)
	entity.next_turn = current_time + turns
	utils.priority_queue_put(queue, entity, entity.next_turn)
end

return time
