local text_runs = {}

local WHITE = { 1, 1, 1, 1 }

function text_runs.run(text, color)
	return { text = text, color = color }
end

function text_runs.fragment(runs, is_player)
	return { runs = runs, is_player = is_player or false }
end

function text_runs.tinted(text, color)
	return text_runs.fragment({ text_runs.run(tostring(text), color) })
end

local function append(plain, colored, text, color)
	if not text or #text == 0 then
		return
	end
	table.insert(plain, text)
	table.insert(colored, color or WHITE)
	table.insert(colored, text)
end

function text_runs.line(...)
	local count = select("#", ...)
	local plain = {}
	local colored = {}
	for i = 1, count do
		local piece = select(i, ...)
		if piece ~= nil then
			if type(piece) == "table" then
				for _, piece_run in ipairs(piece.runs) do
					append(plain, colored, piece_run.text, piece_run.color)
				end
			else
				append(plain, colored, tostring(piece))
			end
		end
	end
	return { text = table.concat(plain), colored = colored }
end

return text_runs
