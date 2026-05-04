local input_handler = require("engine.input")
local ai_handler = require("engine.ai")
local map = require("map.map")
local entities = require("entities.entities")
local ui_handler = require("visuals.ui")

local turn_handler = {}

function turn_handler:update(dt)
	if input_handler:update(dt) then
		local player = entities.player
		map:update_visibility(player.x, player.y, player.stats.sight.sight)
		ai_handler:process_turn()
		ui_handler:update_status(player)
	end
end

return turn_handler
