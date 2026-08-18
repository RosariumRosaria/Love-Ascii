local render_config = require("src.config.render_config")

local grab = {
	index = nil,
	panel = nil,
}

local hand_cursor

local function set_hand_cursor(on)
	if not render_config.hud.grab_cursor then
		return
	end
	if on then
		hand_cursor = hand_cursor or love.mouse.getSystemCursor("hand")
		love.mouse.setCursor(hand_cursor)
	else
		love.mouse.setCursor()
	end
end

function grab:set(index, panel)
	self.index = index
	self.panel = panel
	set_hand_cursor(index ~= nil)
end

function grab:clear()
	self.index = nil
	self.panel = nil
	set_hand_cursor(false)
end

function grab:is_active()
	return self.index ~= nil
end

function grab:holds(panel, index)
	return self.index ~= nil and self.index == index and self.panel == panel
end

return grab
