local input_handler = require("engine.input")
local ai_handler = require("engine.ai")
local map = require("map.map")
local entities = require("entities.entities")
local ui_handler = require("visuals.ui")

local turn_handler = {}

local function convert_speed_to_turns(speed)
	return 10 / speed
end

local function process_ais()
	local entity_list = entities:get_entity_list()
	for _, entity in ipairs(entity_list) do
		if entity.type == "enemy" then
			ai_handler:process_enemy(entity)
		end
	end
end

function turn_handler:update(dt)
	if input_handler:update(dt) then
		local player = entities.player
		map:update_visibility(player.x, player.y, player.stats.sight.sight)
		process_ais()
		ui_handler:update_status(player)
	end
end

return turn_handler
