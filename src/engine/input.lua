local actions = require("src.engine.actions")
local panels = require("src.visuals.ui.panels")
local hud = require("src.visuals.ui.hud")
local debug_input = require("src.debug.debug_input")
local bindings = require("src.config.bindings")
local event_log = require("src.engine.event_log")
local inventory = require("src.sim.inventory")
local aim = require("src.engine.interaction.aim")
local entities = require("src.sim.entities")
local map = require("src.map.map")
local camera = require("src.visuals.camera")
local render_utils = require("src.visuals.render.utils")
local container = require("src.engine.interaction.container")
local cursor = require("src.engine.interaction.cursor")
local game_cfg = require("src.config.game_config")
local utils = require("src.utils")
local pathfinder = require("src.engine.pathfinder")
local state = require("src.engine.state")

local input = {
	actor = nil,
	pending_draw = nil,
	pending_slot = nil,
	down_keys = {},
	pressed_keys = {},
	released_keys = {},
	move_recency = {},
	buffered_keys = {},
	mode = "normal",
	last_turn = { x = 0, y = 0 },
	interact_consumed = false,
	grabbed = nil,
}

local modes = { normal = "normal", aiming = "aiming", container = "container" }

local move_axis_of_key
local function get_move_of_key(key)
	if not move_axis_of_key then
		move_axis_of_key = {}
		for _, k in ipairs(bindings.move_left or {}) do
			move_axis_of_key[k] = { axis = "x", dir = -1 }
		end
		for _, k in ipairs(bindings.move_right or {}) do
			move_axis_of_key[k] = { axis = "x", dir = 1 }
		end
		for _, k in ipairs(bindings.move_up or {}) do
			move_axis_of_key[k] = { axis = "y", dir = -1 }
		end
		for _, k in ipairs(bindings.move_down or {}) do
			move_axis_of_key[k] = { axis = "y", dir = 1 }
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

local function set_mouse_tile()
	local mx, my = love.mouse.getPosition()
	local cx, cy = camera:get_position()
	local x, y = render_utils.get_map_coords(mx, my, cx, cy)
	cursor.set_moused_coords(x, y)
end

function input:reset()
	-- Through set_mode, not a direct assignment, so aim/container get torn down.
	self:set_mode(modes.normal)

	self.actor = nil
	self.down_keys = {}
	self.pressed_keys = {}
	self.released_keys = {}
	self.move_recency = {}
	self.buffered_keys = {}
	self.pending_slot = nil
	self.pending_draw = nil
	self.last_slot = nil
	self.last_turn = { x = 0, y = 0 }
	self.interact_consumed = false
	self.grabbed = nil
end

function love.keypressed(key)
	input.down_keys[key] = true
	input.pressed_keys[key] = true
	if get_move_of_key(key) then
		remove_from_recency(input.move_recency, key)
		table.insert(input.move_recency, key)
	end
end

function love.keyreleased(key)
	input.down_keys[key] = nil
	input.released_keys[key] = true
	if get_move_of_key(key) then
		remove_from_recency(input.move_recency, key)
	end
end

function input:set_actor(entity)
	self.actor = entity
end

function input:get_actor()
	return self.actor
end

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
	local source = self.buffer_reading and self.buffer_set or self.down_keys
	return self:_has(action, source)
end

function input:pressed(action)
	return self:_has(action, self.pressed_keys)
end

function input:pressed_slot()
	for index, key in ipairs(bindings.select_slot or {}) do
		if self.pressed_keys[key] then
			return index
		end
	end
	return nil
end

function input:mouse_over_entity()
	local mx, my = cursor.get_moused_coords()
	local entity_list = entities.get_list_at(mx, my, 1)
	cursor.set_moused_entity(entity_list)
end

local function move_with_mouse(actor)
	local mx, my = cursor.get_moused_coords()

	local tx, ty = map:closest_walkable_neighbor(actor, mx, my, actor.z)
	local target = { x = tx, y = ty }
	local path = pathfinder.a_star({ x = actor.x, y = actor.y }, target, actor, true)
	if path and path[2] then
		local dx = path[2].x - actor.x
		local dy = path[2].y - actor.y
		return { x = utils.sign(dx), y = utils.sign(dy) }
	end
	return { x = 0, y = 0 }
end

local function exit_mode(mode)
	if mode == modes.container then
		container:close()
	elseif mode == modes.aiming then
		aim.exit()
	end
end

function input:set_mode(new_mode)
	if new_mode == self.mode then
		return
	end
	exit_mode(self.mode)
	self.mode = new_mode
	self.pending_slot = nil
	self.last_slot = nil
	self.buffered_keys = {}
end

function input:enter_aim()
	if not aim.enter(self.actor, self.actor.x, self.actor.y) then
		event_log:add({ type = "action_failed", entity = self.actor.name, reason = "no ranged weapon" })
		return false
	end
	self:set_mode(modes.aiming)
	return true
end

function input:get_direction(cardinal_only)
	local x, y = 0, 0

	-- The buffer may hold non-movement keys too, so skip anything that isn't a
	-- direction (get_move_of_key returns nil) rather than assuming a binding.
	local recency = self.buffer_reading and self.buffered_keys or self.move_recency
	for i = #recency, 1, -1 do
		local k = recency[i]
		local binding = get_move_of_key(k)
		if binding then
			if binding.axis == "y" and y == 0 then
				y = binding.dir
			elseif binding.axis == "x" and x == 0 then
				x = binding.dir
			end
			if cardinal_only then
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

	if love.mouse.isDown(1) then
		local mx, my = cursor.get_moused_coords()
		local moused_entity = cursor.get_moused_entity()
		aim.move_to(mx, my, moused_entity)
	end
	return took_action
end

function input:transfer_selected()
	local from, to
	if container.focus_container then
		from, to = container:get(), self.actor
	else
		from, to = self.actor, container:get()
	end
	return actions:handle_action(self.actor, {
		type = "transfer_item",
		from = from,
		to = to,
	})
end

function input:handle_container()
	local took_action = false
	local move_dir = self:get_direction()

	local use_slot = self.pending_slot
	self.pending_slot = nil

	if use_slot then
		local focused = (container.focus_container and container:get()) or self.actor
		if not inventory.set_selected_index(focused, use_slot) then
			return false
		end
		return self:transfer_selected()
	end

	if move_dir.y ~= 0 then
		self:set_mode(modes.normal)
	elseif self:is_down("use_selected") then
		took_action = self:transfer_selected()
	end

	return took_action
end
function input:update(dt)
	set_mouse_tile()

	local game_state = state:get()

	if not self.actor then
		return
	end

	if game_state == "normal" then
		self:mouse_over_entity()
		if self.mode == modes.normal then
			for key in pairs(self.pressed_keys) do
				remove_from_recency(self.buffered_keys, key)
				table.insert(self.buffered_keys, key)
			end
		end

		debug_input:update_actor(self, self.actor)

		if self:pressed("cycle_next") then
			if self.mode == modes.aiming then
				aim.cycle_target()
			else
				local entity = (self.mode == modes.container and container.focus_container and container:get())
					or self.actor
				inventory.increment_selected_index(entity)
			end
		end

		if self.mode == modes.container and (self:pressed("move_left") or self:pressed("move_right")) then
			container:swap_focus()
		end

		if self:pressed("interact") and self.mode == modes.container then
			self:set_mode(modes.normal)
			self.interact_consumed = true
		end

		if self:pressed("aim") then
			if self.mode == modes.aiming then
				self:set_mode(modes.normal)
			else
				local weapon = inventory.get_equipped(self.actor, "mainhand")
				local possible_weapon = inventory.get_first_with_field(self.actor, "ranged")

				if (not weapon or not weapon.ranged) and possible_weapon then
					self.pending_draw = possible_weapon
				elseif not weapon then
					event_log:add({ type = "action_failed", entity = self.actor.name, reason = "no weapon" })
				elseif not weapon.ranged then
					event_log:add({ type = "action_failed", entity = self.actor.name, reason = "no ranged weapon" })
				else
					self:enter_aim()
				end
			end
		end

		local slot = self:pressed_slot()

		local slot_entity = (self.mode == modes.container and container.focus_container and container:get())
			or self.actor

		if slot and inventory.check_index(slot_entity, slot) then
			local now = love.timer.getTime()
			if
				(self.mode == modes.normal or self.mode == modes.container)
				and slot == self.last_slot
				and (now - self.last_slot_time) < game_cfg.timing.turn_delay * 1.5
			then
				self.last_slot = nil
				self.pending_slot = slot
			else
				self.last_slot, self.last_slot_time = slot, now
			end
			inventory.set_selected_index(slot_entity, slot)
		end

		if self:pressed("switch_character") and self.mode == modes.normal then
			hud:switch_character()
		end
	end

	hud:log_events()
end

function input:face(actor, dx, dy)
	if dx == 0 and dy == 0 then
		return
	end
	actor.rotation = math.deg(math.atan2(dy, dx)) % 360
end

function input:try_take_turn()
	local actor = self.actor

	if not actor or actor.dead then
		return false
	end

	local draw_weapon = self.pending_draw

	self.pending_draw = nil

	if draw_weapon then
		local took_action = actions:handle_action(actor, { type = "equip_item", item = draw_weapon })
		self:enter_aim()
		return took_action
	end

	if self.mode == modes.aiming then
		self.pending_draw = nil
		return self:handle_aim()
	elseif self.mode == modes.container then
		self.pending_draw = nil
		return self:handle_container()
	end

	local took_action = self:_take_normal_turn()

	local live_moving = #self.move_recency > 0 or love.mouse.isDown(1)
	if not took_action and not live_moving and #self.buffered_keys > 0 then
		self.buffer_set = {}
		for _, key in ipairs(self.buffered_keys) do
			self.buffer_set[key] = true
		end
		self.buffer_reading = true
		took_action = self:_take_normal_turn()
		self.buffer_reading = false
	end
	self.buffered_keys = {}
	return took_action
end

function input:_take_normal_turn()
	local use_slot = self.pending_slot
	self.pending_slot = nil
	local actor = self.actor
	local took_action = false

	local move_dir = self:get_direction(true)
	if love.mouse.isDown(1) and move_dir.x == 0 and move_dir.y == 0 then
		move_dir = move_with_mouse(actor)
	end
	local is_moving = move_dir.x ~= 0 or move_dir.y ~= 0
	local has_moved = self.last_turn.x ~= 0 or self.last_turn.y ~= 0

	if not is_moving then
		move_dir = self.last_turn
	end
	input:face(actor, move_dir.x, move_dir.y)

	if use_slot then
		if not inventory.set_selected_index(actor, use_slot) then
			return false
		end
		return actions:handle_action(actor, { type = "use_selected", dx = move_dir.x, dy = move_dir.y })
	elseif self:is_down("use_selected") then
		return actions:handle_action(actor, { type = "use_selected", dx = move_dir.x, dy = move_dir.y })
	elseif self:is_down("wait") then
		return actions:handle_action(actor, { type = "wait" })
	end

	if not (is_moving or has_moved) then
		return false
	end

	if self:is_down("attack") then
		local weapon = inventory.get_equipped(actor, "mainhand")
		if weapon and weapon.ranged then
			self:enter_aim()
		else
			took_action = actions:handle_action(actor, {
				type = "attack",
				dx = move_dir.x,
				dy = move_dir.y,
			})
		end
	elseif self:is_down("interact") and not self.interact_consumed then
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

		if took_action and self.mode == modes.normal and container.is_open then
			self:set_mode(modes.container)
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

function input:end_frame()
	self.pressed_keys = {}
	self.released_keys = {}

	if not self:is_down("interact") then
		self.interact_consumed = false
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

return input
