local config = require("config.runtime")
local actions = require("engine.actions")
local scene = require("visuals.render.scene")
local debug_state = require("debug.debug_state")
local panels = require("visuals.panels")
local visualizer = require("debug.visualizer")
local profiler = require("debug.profiler")
local bindings = require("config.bindings")
local event_log = require("engine.event_log")
local inventory = require("items.inventory")
local aim = require("engine.aim")
local entities = require("entities.entities")
local map = require("map.map")
local camera = require("visuals.camera")
local render_utils = require("visuals.render.utils")
local container = require("engine.container")
local cursor = require("engine.cursor")
local prefab = require("map.prefab")
local stats = require("stats.stats")
local game_cfg = require("config.game_config")
local utils = require("utils")
local pathfinder = require("engine.pathfinder")

local input = {
	actor = nil,

	down_keys = {},
	pressed_keys = {},
	released_keys = {},
	move_recency = {},
	buffered_keys = {},
	mode = "normal",
	last_turn = { x = 0, y = 0 },
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
	-- During the buffered-input fallback pass, reads resolve against the keys
	-- captured during the blackout instead of what's physically held now.
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

function input:debug_spawn()
	local mx, my = cursor.get_moused_coords()
	local entity_type = "skeleton"

	if map:is_tile_free(mx, my, 1) then
		entities.add_from_template(entity_type, mx, my, 1)
		event_log:add({ type = "debug", message = "spawned " .. entity_type })
		return
	end
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }
	for _, o in ipairs(offsets) do
		local x, y = mx + o[1], my + o[2]
		if map:is_tile_free(x, y, 1) then
			entities.add_from_template(entity_type, x, y, 1)

			event_log:add({ type = "debug", message = "spawned " .. entity_type })
			return
		end
	end
	event_log:add({ type = "debug", message = "no free cell to spawn " .. entity_type })
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
	self.last_turn = { x = 0, y = 0 }
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

function input:handle_container()
	local took_action = false
	local move_dir = self:get_direction()

	if move_dir.y ~= 0 then
		self:set_mode(modes.normal)
	elseif self:is_down("use_selected") then
		local from, to
		if container.focus_container then
			from, to = container:get(), self.actor
		else
			from, to = self.actor, container:get()
		end
		took_action = actions:handle_action(self.actor, {
			type = "transfer_item",
			from = from,
			to = to,
		})
	end

	return took_action
end
function input:update(dt)
	set_mouse_tile()
	self:mouse_over_entity()

	if not self.actor then
		return
	end

	-- Accumulate this frame's presses so a tap during the post-turn cooldown
	-- (when try_take_turn isn't reached) survives to the next open gate. Same
	-- recency dance as move_recency, but it does NOT forget on key-up — that's
	-- what lets a released tap still register. Cleared when a turn resolves.
	if self.mode == modes.normal then
		for key in pairs(self.pressed_keys) do
			remove_from_recency(self.buffered_keys, key)
			table.insert(self.buffered_keys, key)
		end
	end

	if self:pressed("toggle_grid") then
		debug_state.toggle_grid()
	end

	if self:pressed("toggle_bw") then
		debug_state.toggle_bw()
	end

	if self:pressed("toggle_profiler") then
		profiler:toggle()
	end

	if self:pressed("toggle_perf") then
		debug_state.toggle_perf()
	end

	if self:pressed("toggle_xray") then
		debug_state.toggle_xray()
	end

	if self:pressed("toggle_visualizer") then
		visualizer:toggle()
	end

	if self:pressed("toggle_font") then
		config:toggle_font()
		scene:reload_fonts()
	end

	if self:pressed("switch_offset") then
		debug_state.switch_offset()
	end

	if self:pressed("switch_character") then
		panels:switch_character()
	end

	if self:pressed("quit") then
		if self.mode == modes.container then
			self:set_mode(modes.normal)
		else
			love.event.quit()
		end
	end

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
	end
	if self:pressed("debug") then
		local item = inventory.get_selected(self.actor)
		inventory.add_charge(item)
	end

	if self:pressed("debug_spawn_zombie") then
		self:debug_spawn()
	end

	-- Debug: re-read + re-stamp the configured prefab without restarting (map maker
	-- edit→save→tap-key loop). No-op unless game_config.prefab is set.
	if self:pressed("reload_prefab") and game_cfg.prefab then
		prefab.clear_last()
		prefab.stamp(game_cfg.prefab.file, game_cfg.prefab.ox, game_cfg.prefab.oy)
		map:update_visibility(self.actor.x, self.actor.y, stats.get(self.actor, "sight"))
		event_log:add({ type = "debug", message = "reloaded prefab" })
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

	if slot then
		local now = love.timer.getTime()
		if
			self.mode == modes.normal
			and slot == self.last_slot
			and (now - self.last_slot_time) < game_cfg.timing.turn_delay * 1.5
		then
			self.last_slot = nil
			self.pending_slot = slot
		else
			self.last_slot, self.last_slot_time = slot, now
		end
		local entity = (self.mode == modes.container and container.focus_container and container:get()) or self.actor

		inventory.set_selected_index(entity, slot)
	end

	panels:log_events()
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
		inventory.set_selected_index(actor, use_slot)
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
