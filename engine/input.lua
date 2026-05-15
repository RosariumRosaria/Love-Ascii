local config = require("config.runtime")
local actions = require("engine.actions")
local render = require("visuals.render.render")
local debug_state = require("debug.debug_state")
local ui = require("visuals.ui")
local visualizer = require("map.voronoi.visualizer")
local bindings = require("config.bindings")
local statuses = require("entities.statuses")
local inventory = require("entities.inventory")
local input_handler = {
	actor = nil,

	down_keys = {},
	pressed_keys = {},
	released_keys = {},

	last_turn = { x = 0, y = 0 },
	grabbed = nil,
}

function love.keypressed(key)
	input_handler.down_keys[key] = true
	input_handler.pressed_keys[key] = true
end

function love.keyreleased(key)
	input_handler.down_keys[key] = nil
	input_handler.released_keys[key] = true
end

function input_handler:set_actor(entity)
	self.actor = entity
end

function input_handler:get_actor()
	return self.actor
end

-- internal helper
function input_handler:_has(action, state_table)
	local keys = bindings[action]
	if not keys then
		return false
	end

	for _, key in ipairs(keys) do
		if state_table[key] then
			return true
		end
	end
	return false
end

function input_handler:is_down(action)
	return self:_has(action, self.down_keys)
end

function input_handler:pressed(action)
	return self:_has(action, self.pressed_keys)
end

function input_handler:get_direction()
	local x, y = 0, 0

	if self:is_down("move_left") then
		x = -1
	end
	if self:is_down("move_right") then
		x = 1
	end
	if self:is_down("move_up") then
		y = -1
	end
	if self:is_down("move_down") then
		y = 1
	end

	return { x = x, y = y }
end

function input_handler:update(dt)
	if not self.actor then
		return
	end

	-- debug / instant actions: always processed, not gated by turn cadence
	if self:pressed("toggle_grid") then
		debug_state.toggle_grid()
	end

	if self:pressed("toggle_bw") then
		debug_state.toggle_bw()
	end

	if self:pressed("toggle_normalize_lighting") then
		debug_state.toggle_normalize_lighting()
	end

	if self:pressed("toggle_visualizer") then
		visualizer:toggle()
	end

	if self:pressed("toggle_font") then
		config:toggle_font()
		render:reload_fonts()
	end

	if self:pressed("switch_offset") then
		debug_state.switch_offset()
	end

	if self:pressed("switch_status") then
		ui:switch_status()
	end

	if self:is_down("quit") then
		love.event.quit()
	end

	if self:pressed("increment_selected_index") then
		inventory.increment_selected_index(self.actor)
	end

	if self:pressed("debug") then
		statuses.add_status(self.actor, "regen")
	end

	if self:pressed("debug_2") then
		statuses.add_status(self.actor, "strength")
	end

	ui:log_events()
	ui:update_status(self.actor)
end

function input_handler:try_take_turn()
	local actor = self.actor
	if not actor or actor.dead then
		return false
	end

	if self:is_down("use_selected") then
		return actions:handle_action(actor, { type = "use_selected" })
	end

	local move_dir = self:get_direction()
	local is_moving = move_dir.x ~= 0 or move_dir.y ~= 0
	local has_moved = self.last_turn.x ~= 0 or self.last_turn.y ~= 0

	if not (is_moving or has_moved) then
		return false
	end

	if not is_moving then
		move_dir = self.last_turn
	end

	local took_action = false

	if self:is_down("attack") then
		took_action = actions:handle_action(actor, {
			type = "attack",
			dx = move_dir.x,
			dy = move_dir.y,
		})
	elseif self:is_down("interact") then
		took_action = actions:handle_action(actor, {
			type = "interact",
			dx = move_dir.x,
			dy = move_dir.y,
		})
		if not took_action then
			took_action = actions:handle_action(actor, {
				type = "interact",
				dx = -move_dir.x,
				dy = -move_dir.y,
			})
		end
	elseif self:is_down("inspect") then
		actions:handle_action(actor, {
			type = "inspect",
			dx = move_dir.x,
			dy = move_dir.y,
		})
	elseif self:is_down("place_selected") then
		took_action = actions:handle_action(actor, {
			type = "place_selected",
			dx = move_dir.x,
			dy = move_dir.y,
		})
	elseif is_moving then
		if self:is_down("grab") then
			if not self.grabbed then
				self.grabbed = actions:grab(actor, move_dir.x, move_dir.y)
			end
			if self.grabbed then
				took_action = actions:handle_action(actor, {
					type = "grab_interaction",
					dx = move_dir.x,
					dy = move_dir.y,
					target = self.grabbed,
				})
			end
		else
			self.grabbed = nil
			took_action = actions:handle_action(actor, {
				type = "move",
				dx = move_dir.x,
				dy = move_dir.y,
			})
		end
	end

	self.last_turn = { x = move_dir.x, y = move_dir.y }
	return took_action
end

function input_handler:end_frame()
	self.pressed_keys = {}
	self.released_keys = {}
end

function love.wheelmoved(_, y)
	local term = ui:get_ui("terminal")
	if term then
		term.scroll_offset = math.max(0, term.scroll_offset - y)
	end
end

return input_handler
