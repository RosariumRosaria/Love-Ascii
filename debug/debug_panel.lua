local cursor = require("engine.cursor")
local debug_state = require("debug.debug_state")
local panels = require("visuals.panels")
local effects = require("visuals.effects.effects")
local ai_cfg = require("config.ai_config")
local debug_panel = {}

local target
local last_known
local arrow

-- TODO Someday maybe instead this could be a more general debug panel with different debug states (mind, general describe, stats)
function debug_panel.load()
	panels:add_panel("debug_panel", { x = 25, y = 25, font = "very_small", offset_y = 1.5, auto_size = true })
end

local arrow_chars = {
	["0,-1"] = "^",
	["-1,0"] = "<",
	["1,0"] = ">",
	["0,1"] = "v",
	["1,1"] = "\\",
	["-1,1"] = "/",
	["1,-1"] = "/",
	["-1,-1"] = "\\",
	["0,0"] = ".",
}

function debug_panel.update()
	effects:remove_effect(target)
	effects:remove_effect(last_known)
	effects:remove_effect(arrow)
	local entity = cursor.get_moused_entity()
	local panel = panels:get_panel("debug_panel")
	if not entity or not entity.mind or not debug_state.show_xray then
		panel.visible = false
		panel.anchor = nil
		target, last_known, arrow = nil, nil, nil
		return
	end

	local mind = entity.mind
	panel.anchor = entity
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
		elseif k == "avoid" then
			local stride = ai_cfg.avoid.stride
			local count = 0
			local parts = {}
			for key, penalty in pairs(v) do
				count = count + 1
				local ax = math.floor(key / stride)
				local ay = key % stride
				parts[#parts + 1] = "(" .. ax .. ", " .. ay .. ")=" .. penalty
			end
			val_str = "count: " .. count .. " [" .. table.concat(parts, " ") .. "]"
		else
			val_str = tostring(v)
		end
		panels:add_text_to_panel(panel, key_str .. " = " .. val_str)
	end

	if mind.target_pos then
		target = effects:add_from_template("ping_goal", mind.target_pos.x, mind.target_pos.y, entity.z)
	end
	if mind.last_known then
		last_known = effects:add_from_template("ping_last_known", mind.last_known.x, mind.last_known.y, entity.z)
	end
	if mind.last_heading then
		arrow = effects:add_from_template("arrow", mind.last_known.x, mind.last_known.y, entity.z)
		arrow.panels[1].texts[1] = arrow_chars[mind.last_heading.x .. "," .. mind.last_heading.y]
	end
end

return debug_panel
