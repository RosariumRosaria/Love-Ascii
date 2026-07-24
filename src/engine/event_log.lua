local event_log = { current = {} }

function event_log:reset()
	self.current = {}
end

function event_log:add(ev)
	if ev.spam then
		return
	end
	if ev.x and ev.y then
		-- lazy require: map requires statuses requires event_log, so a top-level require here would cycle
		local map = require("src.map.map")
		if not map:is_visible(ev.x, ev.y) then
			return
		end
	end
	table.insert(event_log.current, ev)
end

function event_log:drain()
	local out = event_log.current
	event_log.current = {}
	return out
end

return event_log
