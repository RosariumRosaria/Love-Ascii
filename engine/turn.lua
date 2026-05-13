local input = require("engine.input")
local ai = require("engine.ai")
local map = require("map.map")
local ui = require("visuals.ui")
local entities = require("entities.entities")
local scheduler = require("engine.scheduler")
local game_cfg = require("config.game_config")
local statuses = require("entities.statuses")

local turn = {
	time_since_last_tick = 0,
	time_between_ticks = game_cfg.timing.turn_delay,
}

local function post_turn_update(player)
	map:update_visibility(player.x, player.y, entities:get_stat(player, "sight"))
	ui:update_status(player)
end

local function commit_turn(actor)
	statuses.tick_entity(actor)
	local popped = scheduler.pop()
	if not actor.dead then
		scheduler.schedule_turn(popped)
	end
end

function turn:update(dt)
	input:update(dt)
	self.time_since_last_tick = self.time_since_last_tick + dt

	local actor = scheduler.peek()
	if not actor then
		input:end_frame()
		return
	end

	if actor ~= input:get_actor() then
		ai:take_turn(actor)
		commit_turn(actor)
		post_turn_update(entities.player)
		input:end_frame()
		return
	end

	if self.time_since_last_tick < self.time_between_ticks then
		input:end_frame()
		return
	end
	self.time_since_last_tick = 0

	if input:try_take_turn() then
		commit_turn(actor)
		post_turn_update(entities.player)
	end

	input:end_frame()
end

return turn
