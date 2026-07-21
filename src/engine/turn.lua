local input = require("src.engine.input")
local ai = require("src.engine.ai")
local map = require("src.map.map")
local panels = require("src.visuals.ui.panels")
local hud = require("src.visuals.ui.hud")
local entities = require("src.sim.entities")
local time = require("src.engine.time")
local game_cfg = require("src.config.game_config")
local statuses = require("src.sim.statuses")
local stats = require("src.sim.stats")
local event_log = require("src.engine.event_log")
local aim = require("src.engine.interaction.aim")
local container = require("src.engine.interaction.container")

local turn = {
	time_since_last_tick = 0,
	time_between_ticks = game_cfg.timing.turn_delay,
}

local function update_character_panel()
	local entity = entities.player
	hud:update_character(entity)
end

local function post_turn_update(player)
	map:update_visibility(player.x, player.y, stats.get(player, "sight"))
end

local function commit_turn(actor)
	if actor == entities.player then
		panels:clear_panel_by_name("terminal")
	end
	statuses.tick_entity(actor)
	map:apply_on_step(actor)

	local popped = time.pop()
	if not actor.dead then
		time.schedule_turn(popped, actor.action_cost)
		actor.action_cost = nil
	end
	hud:log_events()
	if aim.active then
		aim.refresh()
	end
	if actor == entities.player then
		post_turn_update(entities.player)
	end

	hud:update_vitals(entities.player)
	hud:update_statuses(entities.player)
end

function turn:update(dt)
	input:update(dt)
	if not entities.player.dead then
		self.time_since_last_tick = self.time_since_last_tick + dt
		update_character_panel()
		local actor
		local start = love.timer.getTime()
		while true do
			actor = time.peek()
			if not actor or actor == input:get_actor() then
				break
			end -- player is up
			if actor.dead then
				time.pop()
			else
				if statuses.can_act(actor) then
					ai:take_turn(actor)
				end
				commit_turn(actor)
			end
			if (love.timer.getTime() - start) * 1000 > game_cfg.timing.frame_ai_budget then
				input:end_frame()
				return -- resume next frame
			end
		end

		if not actor then
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
		else
			if actor.mind and actor.mind.heard_sounds then
				for _, heard in ipairs(actor.mind.heard_sounds) do
					event_log:add({
						type = "sound",
						description = heard.sound.description,
					})
				end
				actor.mind.heard_sounds = {}
			end
			if input:try_take_turn() then
				commit_turn(actor)
			end
		end
	end
	input:end_frame()
end

return turn
