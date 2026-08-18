local actions = require("src.engine.actions")
local debug_input = require("src.debug.debug_input")
local keys = require("src.engine.keys")
local event_log = require("src.engine.event_log")
local inventory = require("src.sim.inventory")
local aim = require("src.engine.interaction.aim")
local entities = require("src.sim.entities")
local map = require("src.map.map")
local container = require("src.engine.interaction.container")
local grab = require("src.engine.interaction.grab")
local cursor = require("src.engine.interaction.cursor")
local game_cfg = require("src.config.game_config")
local utils = require("src.utils")
local pathfinder = require("src.engine.pathfinder")

local input = {
	actor = nil,
	pending_draw = nil,
	pending_slot = nil,
	mode = "normal",
	last_turn = { x = 0, y = 0 },
	interact_consumed = false,
	grabbed = nil,
}

local modes = { normal = "normal", aiming = "aiming", container = "container" }

function input:reload_keys()
	keys:reload()
end

function input:get_keys(action)
	return keys:get_keys(action)
end

function input:get_last_key()
	return keys:get_last_key()
end

function input:is_down(action)
	return keys:is_down(action)
end

function input:pressed(action)
	return keys:pressed(action)
end

function input:released(action)
	return keys:released(action)
end

function input:pressed_slot()
	return keys:pressed_slot()
end

function input:get_direction(cardinal_only)
	return keys:get_direction(cardinal_only)
end

function input:end_frame()
	keys:end_frame()
	if not self:is_down("interact") then
		self.interact_consumed = false
	end
end

function input:reset()
	self:set_mode(modes.normal)
	self.actor = nil
	self.pending_draw = nil
	self.pending_slot = nil
	self.last_slot = nil
	self.last_turn = { x = 0, y = 0 }
	self.interact_consumed = false
	self.grabbed = nil
	grab:clear()
	keys:reset()
end

function input:set_actor(entity)
	self.actor = entity
end

function input:get_actor()
	return self.actor
end

function input:get_mode()
	return self.mode
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
	keys:clear_buffer()
end

function input:enter_aim()
	if not aim.enter(self.actor, self.actor.x, self.actor.y) then
		event_log:add({ type = "action_failed", entity = self.actor, reason = "no ranged weapon" })
		return false
	end
	self:set_mode(modes.aiming)
	return true
end

function input:queue_slot(slot)
	self.pending_slot = slot
end

function input:confirm_slot(slot, window)
	local now = love.timer.getTime()
	if slot == self.last_slot and (now - self.last_slot_time) < window then
		self.last_slot = nil
		return true
	end
	self.last_slot, self.last_slot_time = slot, now
	return false
end

function input:clear_confirm()
	self.last_slot = nil
end

local function focused_inventory(self)
	if container.focus_container then
		return container:get() or self.actor
	end
	return self.actor
end

local function select_slot(self, entity, allow_queue)
	local slot = self:pressed_slot()
	if not slot or not inventory.check_index(entity, slot) then
		return
	end

	if allow_queue and self:confirm_slot(slot, game_cfg.timing.turn_delay * 1.5) then
		self:queue_slot(slot)
	end
	inventory.set_selected_index(entity, slot)
end

local function draw_or_aim(self)
	local weapon = inventory.get_equipped(self.actor, "mainhand")
	local possible_weapon = inventory.get_first_with_field(self.actor, "ranged")

	if (not weapon or not weapon.ranged) and possible_weapon then
		self.pending_draw = possible_weapon
	elseif not weapon then
		event_log:add({ type = "action_failed", entity = self.actor, reason = "no weapon" })
	elseif not weapon.ranged then
		event_log:add({ type = "action_failed", entity = self.actor, reason = "no ranged weapon" })
	else
		self:enter_aim()
	end
end

local function update_normal(self)
	keys:buffer_pressed()

	if self:pressed("cycle_next") then
		inventory.increment_selected_index(self.actor)
	end

	if self:pressed("aim") then
		draw_or_aim(self)
	end

	select_slot(self, self.actor, true)
end

local function update_container(self)
	if self:pressed("cycle_next") then
		inventory.increment_selected_index(focused_inventory(self))
	end

	if self:pressed("move_left") or self:pressed("move_right") then
		container:swap_focus()
	end

	if self:pressed("interact") then
		self:set_mode(modes.normal)
		self.interact_consumed = true
		return
	end

	if self:pressed("aim") then
		draw_or_aim(self)
		return
	end

	select_slot(self, focused_inventory(self), true)
end

local function update_aiming(self)
	if self:pressed("cycle_next") then
		aim.cycle_target()
	end

	if self:pressed("aim") then
		self:set_mode(modes.normal)
		return
	end

	select_slot(self, self.actor, false)
end

local mode_update = {
	[modes.normal] = update_normal,
	[modes.container] = update_container,
	[modes.aiming] = update_aiming,
}

function input:update(dt)
	if not self.actor then
		return
	end

	debug_input:update_actor(self, self.actor)

	local update_mode = mode_update[self.mode]
	if update_mode then
		update_mode(self)
	end
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
		if not inventory.set_selected_index(focused_inventory(self), use_slot) then
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
		return self:handle_aim()
	elseif self.mode == modes.container then
		return self:handle_container()
	end

	local took_action = self:_take_normal_turn()

	local live_moving = keys:is_moving_live() or love.mouse.isDown(1)
	if not took_action and not live_moving and keys:has_buffer() then
		took_action = keys:read_buffered(function()
			return self:_take_normal_turn()
		end)
	end
	keys:clear_buffer()
	return took_action
end

function input:_take_normal_turn()
	local use_slot = self.pending_slot
	self.pending_slot = nil
	local actor = self.actor
	local took_action = false

	local move_dir = self:get_direction(true)
	if love.mouse.isDown(1) and not cursor.is_over_hud() and move_dir.x == 0 and move_dir.y == 0 then
		move_dir = move_with_mouse(actor)
	end
	local is_moving = move_dir.x ~= 0 or move_dir.y ~= 0
	local has_moved = self.last_turn.x ~= 0 or self.last_turn.y ~= 0

	if not is_moving then
		move_dir = self.last_turn
	end
	entities.face(actor, move_dir.x, move_dir.y)

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
			if not self:is_down("hold_position") then
				took_action = actions:handle_action(actor, {
					type = "move",
					dx = move_dir.x,
					dy = move_dir.y,
				})
			end
		end
	end

	self.last_turn = { x = move_dir.x, y = move_dir.y }
	return took_action
end

return input
