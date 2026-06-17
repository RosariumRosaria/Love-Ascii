local cursor = require("engine.cursor")
local debug_state = require("debug.debug_state")
local panels = require("visuals.panels")
local debug_panel = {}

-- TODO Someday maybe instead this could be a more general debug panel with different debug states (mind, general describe, stats)
function debug_panel.load()
	panels:add_panel("debug_panel", { x = 25, y = 25, font = "very_small" })
end

function debug_panel.update()
	local entity = cursor.get_moused_entity()
	local panel = panels:get_panel("debug_panel")
	if not entity or not entity.mind or not debug_state.show_xray then
		panel.visible = false
		return
	end

	local mind = entity.mind

	panel.visible = true
	panel.texts = {}
	for k, v in pairs(mind) do
		local key_str = tostring(k)
		local val_str
		if type(v) == "table" and v.x then
			val_str = "(" .. v.x .. ", " .. v.y .. ")"
		elseif k == "heard_sounds" then
			local loudness = 0
			local description = ""
			if #v > 0 then
				loudness = v[1].loudness
				description = v[1].sound.description or ""
			end
			val_str = "(" .. "count: " .. #v .. ", " .. "vol: " .. loudness .. ", " .. "desc: " .. description .. ")"
		else
			val_str = tostring(v)
		end
		panels:add_text_to_panel(panel, key_str .. " = " .. val_str)
	end
end

return debug_panel
