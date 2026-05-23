local input = require("engine.input")
local ai = require("engine.ai")
local map = require("map.map")
local ui = require("visuals.ui")
local entities = require("entities.entities")
local scheduler = require("engine.scheduler")
local game_cfg = require("config.game_config")
local statuses = require("statuses.statuses")
local stats = require("stats.stats")
local event_log = require("engine.event_log")
local aim = require("engine.aim")

local turn = {
	time_since_last_tick = 0,
	time_between_ticks = game_cfg.timing.turn_delay,
}

local function post_turn_update(player)
	map:update_visibility(player.x, player.y, stats.get_stat(player, "sight"))
	if aim.active then
		aim.refresh()
	end
	ui:update_status(player)
end

local function commit_turn(actor)
	statuses.tick_entity(actor)
	map:apply_on_step(actor)
	local popped = scheduler.pop()
	if not actor.dead then
		scheduler.schedule_turn(popped)
	end
	ui:log_events()
	post_turn_update(entities.player)
end

function turn:update(dt)
	input:update(dt)
	if not entities.player.dead then
		self.time_since_last_tick = self.time_since_last_tick + dt

		local actor = scheduler.peek()

		if not actor then
			input:end_frame()
			return
		end

		if actor ~= input:get_actor() then
			if statuses.can_act(actor) then
				ai:take_turn(actor)
			end
			commit_turn(actor)
			input:end_frame()
			return
		end

		if self.time_since_last_tick < self.time_between_ticks then
			input:end_frame()
			return
		end

		self.time_since_last_tick = 0

		if not statuses.can_act(actor) then
			commit_turn(actor)
		elseif input:try_take_turn() then
			commit_turn(actor)
		end
	end
	input:end_frame()
end

return turn
