local utils = require("src.utils")
local entities = require("src.sim.entities")
local render_config = require("src.config.render_config")
local text_runs = require("src.visuals.ui.text_runs")
local event_text = {}

local function refer(ev, field)
	local name = ev[field]
	if not name then
		return nil
	end
	if not ev[field .. "_kind"] then
		return text_runs.tinted(string.lower(name))
	end

	local color = ev[field .. "_color"]
	local id = ev[field .. "_id"]
	if id then
		local player = entities.player
		if player and player.id == id then
			return text_runs.fragment({ text_runs.run("you", color) }, true)
		end
	end
	return text_runs.fragment({ text_runs.run("a "), text_runs.run(string.lower(name), color) })
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
		runs[i] = text_runs.run(text, referred_run.color)
	end
	return text_runs.fragment(runs, referred.is_player)
end

local function status_name(ev, capital)
	local name = string.lower(ev.status)
	if capital then
		name = utils.capitalize(name)
	end
	return text_runs.tinted(name, ev.status_color)
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
	return render_config.vitals.damage_text_color
end

function event_text.describe(ev)
	local subject = refer_capital(ev, "entity")

	if ev.type == "combat" then
		local quality = ""
		if ev.quality == "glance" then
			quality = "glancing "
		end
		if ev.quality == "solid" then
			quality = "precise "
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
			local runs = { text_runs.run(" (") }
			for i, entry in ipairs(tally) do
				if i > 1 then
					table.insert(runs, text_runs.run(", "))
				end
				table.insert(runs, text_runs.run(tostring(entry.amount), entry.color))
				table.insert(runs, text_runs.run(entry.label))
			end
			table.insert(runs, text_runs.run(")"))
			suffix = text_runs.fragment(runs)
		end

		return text_runs.line(
			refer_capital(ev, "source"),
			" landed a ",
			quality,
			"blow on ",
			refer(ev, "entity"),
			".",
			suffix
		)
	elseif ev.type == "damage" then
		return text_runs.line(
			subject,
			" took damage from ",
			refer(ev, "source"),
			". (",
			text_runs.tinted(ev.amount, render_config.vitals.damage_text_color),
			" damage)"
		)
	elseif ev.type == "heal" then
		return text_runs.line(
			subject,
			" was healed by ",
			refer(ev, "source"),
			". (",
			text_runs.tinted(ev.amount, render_config.vitals.heal_text_color),
			" healed)"
		)
	elseif ev.type == "status_applied" then
		if ev.source then
			return text_runs.line(refer_capital(ev, "source"), " inflicted ", status_name(ev), " on ", refer(ev, "entity"), ".")
		end
		return text_runs.line(status_name(ev, true), " took hold of ", refer(ev, "entity"), ".")
	elseif ev.type == "status_expired" then
		return text_runs.line(status_name(ev, true), " wore off ", refer(ev, "entity"), ".")
	elseif ev.type == "entity_died" then
		if subject then
			return text_runs.line(subject, " ", was(subject.is_player), " killed by ", refer(ev, "source"), ".")
		end
	elseif ev.type == "entity_dragged" then
		return text_runs.line(
			refer_capital(ev, "source"),
			" dragged ",
			refer(ev, "entity"),
			" to ",
			ev.dest_x,
			", ",
			ev.dest_y,
			"."
		)
	elseif ev.type == "item_spent_on" then
		return text_runs.line(
			refer_capital(ev, "source"),
			" ",
			ev.verb,
			" ",
			refer(ev, "entity"),
			" with ",
			refer(ev, "item"),
			"."
		)
	elseif ev.type == "entity_picked_up" then
		return text_runs.line(refer_capital(ev, "source"), " picked up ", refer(ev, "entity"), ".")
	elseif ev.type == "entity_placed" then
		return text_runs.line(refer_capital(ev, "source"), " placed ", refer(ev, "entity"), ".")
	elseif ev.type == "item_equipped" then
		return text_runs.line(subject, " equipped ", refer(ev, "item"), ". (", ev.slot, ")")
	elseif ev.type == "item_unequipped" then
		return text_runs.line(subject, " unequipped ", refer(ev, "item"), ". (", ev.slot, ")")
	elseif ev.type == "item_used" then
		return text_runs.line(subject, " used ", refer(ev, "item"), ".")
	elseif ev.type == "ammo_broke" then
		if subject and subject.is_player then
			return text_runs.line("Your ", string.lower(ev.item), " broke!")
		end
		return text_runs.line(subject, "'s ", string.lower(ev.item), " broke!")
	elseif ev.type == "item_consumed" then
		return text_runs.line(refer_capital(ev, "item"), " was used up.")
	elseif ev.type == "entity_waited" then
		return text_runs.line(subject, " waited.")
	elseif ev.type == "describe" then
		return text_runs.line(subject, ": ", ev.description)
	elseif ev.type == "action_failed" then
		return text_runs.line(subject, " could not: ", string.lower(ev.reason), ".")
	elseif ev.type == "sound" then
		return text_runs.line("You heard ", ev.description, ".")
	elseif ev.type == "debug" then
		return text_runs.line("[DEBUG] ", ev.message)
	end
end

return event_text
