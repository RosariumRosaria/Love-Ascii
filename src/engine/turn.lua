local input = require("src.engine.input")
local ai = require("src.engine.ai")
local map = require("src.map.map")
local entities = require("src.sim.entities")
local time = require("src.engine.time")
local game_cfg = require("src.config.game_config")
local statuses = require("src.sim.statuses")
local event_log = require("src.engine.event_log")
local aim = require("src.engine.interaction.aim")

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
	end
end

function turn:update(dt)
	self.time_since_last_tick = self.time_since_last_tick + dt
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
			return -- resume next frame
		end
	end

	if not actor then
		return
	end

	if self.time_since_last_tick < self.time_between_ticks then
		return
	end

	self.time_since_last_tick = 0

	if not statuses.can_act(actor) then
		commit_turn(actor)
	else
		if actor.mind and actor.mind.heard_sounds then
			for _, heard in ipairs(actor.mind.heard_sounds) do
				if not map:is_visible(math.floor(heard.sound.x), math.floor(heard.sound.y)) or heard.loudness > 4 then
					event_log:add({ type = "sound", description = heard.sound.description })
				end
			end
			actor.mind.heard_sounds = {}
		end
		if input:try_take_turn() then
			commit_turn(actor)
		end
	end
end

return turn
