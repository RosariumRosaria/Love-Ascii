local config = require("config.runtime")
local actions = require("engine.actions")
local render = require("visuals.render.render")
local debug_state = require("debug.debug_state")
local ui = require("visuals.ui")
local visualizer = require("debug.visualizer")
local bindings = require("config.bindings")
local event_log = require("engine.event_log")
local inventory = require("items.inventory")
local aim = require("engine.aim")

local input = {
	actor = nil,

	down_keys = {},
	pressed_keys = {},
	released_keys = {},
	move_recency = {},
	mode = "normal",
	last_turn = { x = 0, y = 0 },
	grabbed = nil,
}

local modes = { normal = "normal", aiming = "aiming" }

local move_axis_of_key
local function get_move_axis(key)
	if not move_axis_of_key then
		move_axis_of_key = {}
		for _, k in ipairs(bindings.move_left or {}) do
			move_axis_of_key[k] = "x"
		end
		for _, k in ipairs(bindings.move_right or {}) do
			move_axis_of_key[k] = "x"
		end
		for _, k in ipairs(bindings.move_up or {}) do
			move_axis_of_key[k] = "y"
		end
		for _, k in ipairs(bindings.move_down or {}) do
			move_axis_of_key[k] = "y"
		end
	end
	return move_axis_of_key[key]
end

local function remove_from_recency(list, key)
	for i, k in ipairs(list) do
		if k == key then
			table.remove(list, i)
			return
		end
	end
end

function love.keypressed(key)
	input.down_keys[key] = true
	input.pressed_keys[key] = true
	if get_move_axis(key) then
		remove_from_recency(input.move_recency, key)
		table.insert(input.move_recency, key)
	end
end

function love.keyreleased(key)
	input.down_keys[key] = nil
	input.released_keys[key] = true
	if get_move_axis(key) then
		remove_from_recency(input.move_recency, key)
	end
end

function input:set_actor(entity)
	self.actor = entity
end

function input:get_actor()
	return self.actor
end

-- internal helper
function input:_has(action, state_table)
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

function input:is_down(action)
	return self:_has(action, self.down_keys)
end

function input:pressed(action)
	return self:_has(action, self.pressed_keys)
end

function input:get_direction(cardinal_only)
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

	if cardinal_only and x ~= 0 and y ~= 0 then
		for i = #self.move_recency, 1, -1 do
			local k = self.move_recency[i]
			if self.down_keys[k] then
				if get_move_axis(k) == "x" then
					y = 0
				else
					x = 0
				end
				break
			end
		end
	end

	return { x = x, y = y }
end

function input:handle_aim()
	local took_action = false
	local move_dir = self:get_direction()
	local is_moving = move_dir.x ~= 0 or move_dir.y ~= 0

	if is_moving then
		aim.move(move_dir.x, move_dir.y)
	elseif self:is_down("attack") then
		took_action = actions:handle_action(self.actor, {
			type = "ranged_attack",
			target_x = aim.x,
			target_y = aim.y,
		})
	end
	return took_action
end

function input:update(dt)
	if not self.actor then
		return
	end

	if self:pressed("toggle_grid") then
		debug_state.toggle_grid()
	end

	if self:pressed("toggle_bw") then
		debug_state.toggle_bw()
	end

	if self:pressed("toggle_normalize_lighting") then
		debug_state.toggle_normalize_lighting()
	end

	if self:pressed("toggle_perf") then
		debug_state.toggle_perf()
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

	if self:pressed("cycle_next") then
		if self.mode == modes.aiming then
			aim.cycle_target()
		else
			inventory.increment_selected_index(self.actor)
		end
	end
	if self:pressed("debug") then
		local item = inventory.get_selected(self.actor)
		inventory.add_charge(item)
	end

	if self:pressed("aim") then
		if self.mode == modes.aiming then
			self.mode = modes.normal
			aim.exit()
			self.last_turn = { x = 0, y = 0 }
		else
			local weapon = inventory.get_equipped(self.actor, "mainhand")
			if not weapon or not weapon.ranged then
				event_log:add({ type = "action_failed", entity = self.actor.name, reason = "no ranged weapon" })
			else
				self.mode = modes.aiming
				aim.enter(self.actor, self.actor.x, self.actor.y)
				self.last_turn = { x = 0, y = 0 }
			end
		end
	end

	ui:log_events()
	ui:update_status(self.actor)
end

function input:try_take_turn()
	local actor = self.actor
	if not actor or actor.dead then
		return false
	end

	local took_action = false

	if self.mode == modes.aiming then
		return self:handle_aim()
	else
		if self:is_down("use_selected") then
			return actions:handle_action(actor, { type = "use_selected" })
		elseif self:is_down("wait") then
			return actions:handle_action(actor, { type = "wait" })
		end

		local move_dir = self:get_direction(true)
		local is_moving = move_dir.x ~= 0 or move_dir.y ~= 0
		local has_moved = self.last_turn.x ~= 0 or self.last_turn.y ~= 0

		if not (is_moving or has_moved) then
			return false
		end

		if not is_moving then
			move_dir = self.last_turn
		end

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
	end
	return took_action
end

function input:end_frame()
	self.pressed_keys = {}
	self.released_keys = {}
end

function love.wheelmoved(_, y)
	local term = ui:get_ui("terminal")
	if term then
		term.scroll_offset = math.max(0, term.scroll_offset - y)
	end
end

return input
