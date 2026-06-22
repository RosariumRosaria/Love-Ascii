local event_log = { current = {} }

function event_log:add(ev)
	if not ev.spam then
		table.insert(event_log.current, ev)
	end
end

function event_log:drain()
	local out = event_log.current
	event_log.current = {}
	return out
end

return event_log
