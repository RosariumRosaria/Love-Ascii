local input = require("src.engine.input")
local menu = require("src.visuals.ui.menu")
local settings = require("src.config.settings")
local entities = require("src.sim.entities")
local hud = require("src.visuals.ui.hud")
local menu_control = require("src.app.menu_control")

local flow = {
	game_state = "start",
}

local states = {
	normal = "normal",
	paused = "paused",
	dead = "dead",
	start = "start",
	settings = "settings",
	keybinds = "keybinds",
}

local menu_for_state =
	{ paused = "pause", start = "start", dead = "dead", settings = "settings", keybinds = "keybinds" }

local queue = {}

local function put(node)
	table.insert(queue, 1, node)
end

local function pop()
	local head = queue[1]
	table.remove(queue, 1)
	return head
end

function flow:get_state()
	return self.game_state
end

function flow:set_state(new_state, going_back)
	local previous = self.game_state
	menu_control.reset()

	local current = states[new_state]
	if not current then
		return false
	end
	self.game_state = current

	local leaving = previous ~= current and menu_for_state[previous]
	if leaving then
		if not going_back and new_state ~= "normal" then
			put(previous)
		end
		menu:set_visible(leaving, false)
	end

	local entering = menu_for_state[current]
	if entering then
		if current == "dead" then
			menu:set_death_reason("Killed by a " .. (entities.player.death_source or "Unknown"))
		end

		menu:set_visible(entering, true)
	end

	hud:set_visible(current == "normal")
	return true
end

function flow:go_back()
	self:set_state(pop(), true)
	settings:save()
	settings:save_keybinds()
end

function flow:update()
	local game_state = self.game_state

	if game_state == "normal" then
		if entities.player and entities.player.dead then
			self:set_state("dead")
			return
		end
		if input:pressed("pause") then
			self:set_state("paused")
		end
		return
	end
	if game_state == "paused" and input:pressed("pause") then
		self:set_state("normal")
		return
	end

	if game_state == "settings" and input:pressed("pause") then
		self:go_back()
		return
	end

	if game_state == "keybinds" and not menu_control.is_capturing() and input:pressed("pause") then
		self:go_back()
		return
	end

	local name = menu_for_state[game_state]
	if name then
		menu_control.update(self, name)
	end
end

return flow
