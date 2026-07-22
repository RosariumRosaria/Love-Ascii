local state = {
	game_state = "normal",
}

local states = { normal = "normal", paused = "paused", dead = "dead" }

function state:get()
	return self.game_state
end

function state:set(game_state)
	local new_state = states[game_state]
	if not game_state or not new_state then
		return
	end
	self.game_state = new_state
end

return state
