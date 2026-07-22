local state = {
	game_state = "start",
}

local states = { normal = "normal", paused = "paused", dead = "dead", start = "start" }

function state:get()
	return self.game_state
end

function state:set(game_state)
	local new_state = states[game_state]
	if not game_state or not new_state then
		return false
	end
	self.game_state = new_state
	return true
end

return state
