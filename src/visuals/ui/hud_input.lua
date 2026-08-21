local panels = require("src.visuals.ui.panels")
local hud = require("src.visuals.ui.hud")
local inventory = require("src.sim.inventory")
local entities = require("src.sim.entities")
local container = require("src.engine.interaction.container")
local grab = require("src.engine.interaction.grab")
local cursor = require("src.engine.interaction.cursor")
local camera = require("src.visuals.camera")
local render_utils = require("src.visuals.render.utils")
local game_cfg = require("src.config.game_config")

local hud_input = {}

local HOVER_PANELS = { "character", "container" }
local BLOCKING_PANELS = { "character", "container", "equipment" }

local last_panel, last_i
local last_mode

local function hovered_row()
	local mx, my = love.mouse.getPosition()
	for _, name in ipairs(HOVER_PANELS) do
		local panel = panels:get_panel(name)
		local i = panels:row_at(panel, mx, my)
		if i then
			return name, i, panel
		end
	end
end

local function hovered_slot()
	local mx, my = love.mouse.getPosition()
	for _, name in ipairs(HOVER_PANELS) do
		local panel = panels:get_panel(name)
		local i = panels:nearest_row(panel, mx, my)
		if i then
			return name, i, panel
		end
	end
end

local function mouse_over_hud()
	local mx, my = love.mouse.getPosition()
	for _, name in ipairs(BLOCKING_PANELS) do
		if panels:mouse_in(panels:get_panel(name), mx, my) then
			return true
		end
	end
	return false
end

local function update_world_cursor(actor)
	local mx, my = love.mouse.getPosition()
	local cx, cy = camera:get_position()
	local x, y = render_utils.get_map_coords(mx, my, cx, cy)
	cursor.set_moused_coords(x, y)

	if not actor or cursor.is_over_hud() then
		cursor.set_moused_entity(nil)
		return
	end

	cursor.set_moused_entity(entities.get_list_at(x, y, 1))
end

local function update_hover(input, mode)
	if mode == "aiming" then
		return
	end

	local name, i, panel = hovered_row()
	if not name or (name == "container" and mode ~= "container") then
		return
	end
	if name == last_panel and i == last_i then
		return
	end
	last_panel, last_i = name, i

	if mode == "container" then
		container:set_focus(name == "container")
	end

	local entity = (name == "container" and container:get()) or panel.entity or input:get_actor()
	inventory.set_selected_index(entity, i)
end

local function update_grab(input, mode)
	if input:pressed("click_hud") and (mode == "normal" or mode == "container") then
		local _, i, panel = hovered_row()
		grab:set(i, panel)
	end

	if not (input:released("click_hud") and grab:is_active()) then
		return
	end

	local name, i, panel = hovered_slot()
	if (i == grab.index or i == grab.index + 1) and (name == "character" or mode == "container") then
		if mode == "container" or input:confirm_slot(grab.index, game_cfg.timing.double_click) then
			input:queue_slot(grab.index)
		end
	elseif i and panel == grab.panel then
		inventory.move_to(panel.entity, grab.index, i)
		input:clear_confirm()
	end
	grab:clear()
end

function hud_input:reset()
	last_panel, last_i = nil, nil
	last_mode = nil
end

function hud_input:update(input)
	local actor = input:get_actor()
	cursor.set_over_hud(mouse_over_hud())
	update_world_cursor(actor)

	if not actor then
		return
	end

	local mode = input:get_mode()
	if mode ~= last_mode then
		last_mode = mode
		last_panel, last_i = nil, nil
	end

	update_hover(input, mode)
	update_grab(input, mode)

	if input:pressed("switch_character") and mode == "normal" then
		hud:switch_character()
	end
end

function love.wheelmoved(_, y)
	if cursor.scroll_entity(-y) then
		return
	end
	local term = panels:get_panel("terminal")
	if term then
		term.scroll_offset = math.max(0, term.scroll_offset - y)
	end
end

return hud_input
