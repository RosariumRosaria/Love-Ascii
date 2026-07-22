local entities = require("src.sim.entities")
local inventory = require("src.sim.inventory")
local state = require("src.engine.state")

local map = require("src.map.map")
local panels = require("src.visuals.ui.panels")
local session = {}

function session.load()
	local player = entities.add_from_template("player", 250, 250, 1)
	entities.set_player(player)

	inventory.add_from_template(player, "sword")
	inventory.add_from_template(player, "bow")
	inventory.add_from_template(player, "leather_armor")
	inventory.add_from_template(player, "torch", {
		name = "Lantern",
		key = "Lantern",
		chars = { "8" },
		color = { { 1, 0.8, 0.6, 1 } },
		light = {
			color = { r = 1.0, g = 0.85, b = 0.65 },
			flicker = { amp = 0.1, freq = 2, phase = 6 },
			intensity = 0.5,
			radius = 10,
		},
	})
	inventory.add_from_template(player, "plank")
	inventory.add_from_template(player, "bandage")
	inventory.add_from_template(player, "health_potion")
	inventory.add_from_template(player, "arrow", { charges = 3 })

	inventory.equip(player, player.inventory.items[1])
	inventory.equip(player, player.inventory.items[3])
	inventory.equip(player, player.inventory.items[4])
	state:set("normal")
end

function session.respawn()
	local player = entities.add_from_template_free("player", 250, 250, 1)
	entities.set_player(player)
	state:set("normal")
	panels:get_panel("dead").visible = false
	panels:get_panel("death_reason").visible = false
	map:update_visibility(entities.player)
end
return session
