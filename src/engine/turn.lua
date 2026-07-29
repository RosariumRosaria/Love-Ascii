local input = require("src.engine.input")
local ai = require("src.engine.ai")
local map = require("src.map.map")
local entities = require("src.sim.entities")
local time = require("src.engine.time")
local game_cfg = require("src.config.game_config")
local statuses = require("src.sim.statuses")
local event_log = require("src.engine.event_log")
local aim = require("src.engine.interaction.aim")
local director = require("src.engine.director")

local turn = {
	time_since_last_tick = 0,
	time_between_ticks = game_cfg.timing.turn_delay,
}

local function commit_turn(actor)
	statuses.tick_entity(actor)
	map:apply_on_step(actor)

	local popped = time.pop()
	if not actor.dead then
		time.schedule_turn(popped, actor.action_cost)
		actor.action_cost = nil
	end
	if aim.active then
		aim.refresh()
	end
	if actor == entities.player then
		map:update_visibility(entities.player)
		director:tick()
	end
end

local function advance_to_player()
	local start = love.timer.getTime()
	while true do
		local actor = time.peek()
		if not actor then
			return nil
		end
		if actor == input:get_actor() then
			return actor
		end
		if actor.dead then
			time.pop()
		else
			if statuses.can_act(actor) then
				ai:take_turn(actor)
			end
			commit_turn(actor)
		end
		if (love.timer.getTime() - start) * 1000 > game_cfg.timing.frame_ai_budget then
			return nil
		end
	end
end

local function log_heard_sounds(player)
	if not (player.mind and player.mind.heard_sounds) then
		return
	end
	for _, heard in ipairs(player.mind.heard_sounds) do
		if not map:is_visible(math.floor(heard.sound.x), math.floor(heard.sound.y)) or heard.loudness > 10 then --TODO MAKE CONFIG
			event_log:add({ type = "sound", description = heard.sound.description })
		end
	end
	player.mind.heard_sounds = {}
end

local function try_player_turn(player)
	if not statuses.can_act(player) then
		commit_turn(player)
		return
	end
	log_heard_sounds(player)
	if input:try_take_turn() then
		commit_turn(player)
	end
end

function turn:update(dt)
	self.time_since_last_tick = self.time_since_last_tick + dt

	local player = advance_to_player()
	if not player then
		return
	end

	if self.time_since_last_tick < self.time_between_ticks then
		return
	end
	self.time_since_last_tick = 0

	try_player_turn(player)
end

return turn
