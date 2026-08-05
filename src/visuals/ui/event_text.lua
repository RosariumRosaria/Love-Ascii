local utils = require("src.utils")
local entities = require("src.sim.entities")
local render_config = require("src.config.render_config")
local event_text = {}

local WHITE = { 1, 1, 1, 1 }

local function run(text, color)
	return { text = text, color = color }
end

local function fragment(runs, is_player)
	return { runs = runs, is_player = is_player or false }
end

local function append(plain, colored, text, color)
	if not text or #text == 0 then
		return
	end
	table.insert(plain, text)
	table.insert(colored, color or WHITE)
	table.insert(colored, text)
end

local function line(...)
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

local function refer(ev, field)
	local name = ev[field]
	if not name then
		return nil
	end
	if not ev[field .. "_kind"] then
		return fragment({ run(string.lower(name)) })
	end

	local color = ev[field .. "_color"]
	local id = ev[field .. "_id"]
	if id then
		local player = entities.player
		if player and player.id == id then
			return fragment({ run("you", color) }, true)
		end
	end
	return fragment({ run("a "), run(string.lower(name), color) })
end

local function refer_capital(ev, field)
	local referred = refer(ev, field)
	if not referred then
		return nil
	end
	local runs = {}
	for i, referred_run in ipairs(referred.runs) do
		local text = referred_run.text
		if i == 1 then
			text = utils.capitalize(text)
		end
		runs[i] = run(text, referred_run.color)
	end
	return fragment(runs, referred.is_player)
end

local function was(is_player)
	return is_player and "were" or "was"
end

local function combat_color(quality)
	local cfg = render_config.combat
	if quality == "glance" then
		return cfg.glance_text_color
	end
	if quality == "solid" then
		return cfg.solid_text_color
	end
	return cfg.strike_text_color
end

local function tinted(text, color)
	return fragment({ run(tostring(text), color) })
end

function event_text.describe(ev)
	local subject = refer_capital(ev, "entity")

	if ev.type == "combat" then
		local quality = ""
		if ev.quality == "glance" then
			quality = "glancing "
		end
		if ev.quality == "solid" then
			quality = "solid "
		end

		local tally = {}
		if ev.amount > 0 then
			tally[#tally + 1] = { amount = ev.amount, color = combat_color(ev.quality), label = " damage" }
		end
		if ev.absorbed and ev.absorbed > 0 then
			tally[#tally + 1] = { amount = ev.absorbed, label = " absorbed by their " .. ev.absorbed_by }
		end
		local suffix
		if #tally > 0 then
			local runs = { run(" (") }
			for i, entry in ipairs(tally) do
				if i > 1 then
					table.insert(runs, run(", "))
				end
				table.insert(runs, run(tostring(entry.amount), entry.color))
				table.insert(runs, run(entry.label))
			end
			table.insert(runs, run(")"))
			suffix = fragment(runs)
		end

		return line(refer_capital(ev, "source"), " landed a ", quality, "blow on ", refer(ev, "entity"), ".", suffix)
	elseif ev.type == "damage" then
		return line(
			subject,
			" took damage from ",
			refer(ev, "source"),
			". (",
			tinted(ev.amount, render_config.vitals.damage_text_color),
			" damage)"
		)
	elseif ev.type == "heal" then
		return line(
			subject,
			" recovered from ",
			refer(ev, "source"),
			". (",
			tinted(ev.amount, render_config.vitals.heal_text_color),
			" healed)"
		)
	elseif ev.type == "status_applied" then
		if ev.source then
			return line(
				refer_capital(ev, "source"),
				" inflicted ",
				string.lower(ev.status),
				" on ",
				refer(ev, "entity"),
				"."
			)
		end
		return line(utils.capitalize(string.lower(ev.status)), " took hold of ", refer(ev, "entity"), ".")
	elseif ev.type == "status_expired" then
		return line(utils.capitalize(string.lower(ev.status)), " wore off ", refer(ev, "entity"), ".")
	elseif ev.type == "entity_died" then
		if subject then
			return line(subject, " ", was(subject.is_player), " killed by ", refer(ev, "source"), ".")
		end
	elseif ev.type == "entity_dragged" then
		return line(
			refer_capital(ev, "source"),
			" dragged ",
			refer(ev, "entity"),
			" to ",
			ev.dest_x,
			", ",
			ev.dest_y,
			"."
		)
	elseif ev.type == "entity_picked_up" then
		return line(refer_capital(ev, "source"), " picked up ", refer(ev, "entity"), ".")
	elseif ev.type == "entity_placed" then
		return line(refer_capital(ev, "source"), " placed ", refer(ev, "entity"), ".")
	elseif ev.type == "item_equipped" then
		return line(subject, " equipped ", refer(ev, "item"), ". (", ev.slot, ")")
	elseif ev.type == "item_unequipped" then
		return line(subject, " unequipped ", refer(ev, "item"), ". (", ev.slot, ")")
	elseif ev.type == "item_used" then
		return line(subject, " used ", refer(ev, "item"), ".")
	elseif ev.type == "ammo_broke" then
		if subject and subject.is_player then
			return line("Your ", string.lower(ev.item), " broke!")
		end
		return line(subject, "'s ", string.lower(ev.item), " broke!")
	elseif ev.type == "item_consumed" then
		return line(refer_capital(ev, "item"), " was used up.")
	elseif ev.type == "entity_waited" then
		return line(subject, " waited.")
	elseif ev.type == "describe" then
		return line(subject, ": ", ev.description)
	elseif ev.type == "action_failed" then
		return line(subject, " could not: ", string.lower(ev.reason), ".")
	elseif ev.type == "sound" then
		return line("You heard ", ev.description, ".")
	elseif ev.type == "debug" then
		return line("[DEBUG] ", ev.message)
	end
end

return event_text
