local cursor = require("engine.cursor")
local debug_state = require("debug.debug_state")
local panels = require("visuals.panels")
local debug_panel = {}

function debug_panel.update()
	local entity = cursor.get_moused_entity()
	if not entity or not entity.mind or not debug_state.show_xray then
		return
	end
	local mind = entity.mind
end

return debug_panel
