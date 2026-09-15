local status_types = require("src.sim.status_types")
local text_runs = require("src.visuals.ui.text_runs")
local combat = require("src.engine.combat")
local item_text = {}

local GOOD = { 0.55, 0.80, 0.55, 1 }
local BAD = { 0.85, 0.45, 0.45, 1 }
local LABEL = { 0.80, 0.80, 0.80, 1 }

local FLAVOR_ALPHA = 0.75
local FOOTER_ALPHA = 0.75

local STAT_NAMES = {
	damage_spread = "variance",
	accuracy = "accuracy",
	evasion = "evasion",
	piercing = "piercing",
	stealth = "stealth",
	speed = "speed",
}

local function stat_name(stat)
	return STAT_NAMES[stat] or (stat:gsub("_", " "))
end

local function dimmed(entry, alpha)
	entry.alpha = alpha
	return entry
end

local function separate(out)
	if #out > 0 and out[#out] ~= "" then
		table.insert(out, "")
	end
end

local function context_of(mod)
	return mod.context and (" (" .. mod.context .. ")") or ""
end

local function title(out, item)
	local color = item.color and item.color[1]
	table.insert(out, text_runs.line(text_runs.tinted(item.name or item.key, color)))

	table.insert(out, text_runs.line("---"))
end

local function damage_line(out, item, mod, entity)
	local context = item.ranged and "ranged" or "melee"
	local glance, hit, solid = combat.damage_bands(entity, context, item)

	table.insert(
		out,
		text_runs.line(text_runs.tinted(glance .. "-" .. hit .. "-" .. solid, GOOD), context_of(mod))
	)
end

local function modifier_line(out, mod)
	local amount, good
	if mod.op == "mul" then
		amount = "x" .. mod.value
		good = mod.value >= 1
	else
		amount = (mod.value >= 0 and "+" or "-") .. math.abs(mod.value)
		good = mod.value >= 0
	end

	table.insert(
		out,
		text_runs.line(text_runs.tinted(amount, good and GOOD or BAD), " " .. stat_name(mod.stat) .. context_of(mod))
	)
end

local function modifiers(out, item, entity)
	if not item.modifiers then
		return
	end

	separate(out)
	local bands = item.slot == "mainhand"
	for _, mod in ipairs(item.modifiers) do
		if mod.stat == "damage" and bands then
			damage_line(out, item, mod, entity)
		elseif mod.stat ~= "damage_spread" or not bands then
			modifier_line(out, mod)
		end
	end
end

local function status_ref(name)
	local status = status_types[name]
	return text_runs.tinted(status and status.name or name, status and status.color)
end

local function treated_refs(tag)
	local refs = {}
	for key, status in pairs(status_types) do
		if status.tags and status.tags[tag] then
			table.insert(refs, key)
		end
	end
	table.sort(refs)

	local line = {}
	for i, key in ipairs(refs) do
		if i > 1 then
			table.insert(line, i == #refs and " and " or ", ")
		end
		table.insert(line, status_ref(key))
	end
	return line
end

local function on_use(out, item)
	local use = item.on_use
	if use.apply_status then
		table.insert(out, text_runs.line("Applies ", status_ref(use.apply_status)))
	end
	if use.clear_status then
		local refs = treated_refs(use.clear_status)
		if #refs > 0 then
			table.insert(out, text_runs.line("Treats ", unpack(refs)))
		end
	end
	if use.targets then
		table.insert(out, "")
		table.insert(out, "Used on a nearby target")
	end
end

local function effects(out, item)
	if item.on_use then
		separate(out)
		on_use(out, item)
	end

	if item.applies_on_hit then
		separate(out)
		for _, applied in ipairs(item.applies_on_hit) do
			if applied.chance then
				table.insert(
					out,
					text_runs.line(applied.chance .. "% to inflict ", status_ref(applied.name), " on hit")
				)
			else
				table.insert(out, text_runs.line("Inflicts ", status_ref(applied.name), " on hit"))
			end
		end
	end
end

local function footer(out, item)
	if not (item.slot or item.volume or item.charges) then
		return
	end

	separate(out)
	if item.slot then
		table.insert(out, dimmed(text_runs.line("Slot: ", text_runs.tinted(item.slot, LABEL)), FOOTER_ALPHA))
	end
	if item.volume then
		table.insert(out, dimmed(text_runs.line("Volume: ", text_runs.tinted(item.volume, LABEL)), FOOTER_ALPHA))
	end
	if item.charges then
		local charges = item.charges .. (item.max_charges and ("/" .. item.max_charges) or "")
		table.insert(out, dimmed(text_runs.line("Charges: ", text_runs.tinted(charges, LABEL)), FOOTER_ALPHA))
	end
end

local function flavor(out, item)
	if item.description then
		separate(out)
		table.insert(out, dimmed(text_runs.line(item.description), FLAVOR_ALPHA))
	end
end

function item_text.lines(item, entity)
	local out = {}
	title(out, item)
	modifiers(out, item, entity)
	effects(out, item)
	footer(out, item)
	flavor(out, item)

	return out
end

return item_text
