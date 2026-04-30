local config = require("config")
local game_cfg = require("config.game_config")
local map = require("map.map")
local render_handler = require("visuals.render_handler")
local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local input_handler = require("engine.input_handler")
local visualizer = require("voroni.visualizer")
local entities = require("entities.entities")

local ai_handler = require("engine.ai_handler")

_G.deep_print = function(tbl, indent, visited) --TODO Gross, for debug
	indent = indent or 0
	visited = visited or {}

	if visited[tbl] then
		print(string.rep("  ", indent) .. "*recursive reference*")
		return
	end
	visited[tbl] = true

	for k, v in pairs(tbl) do
		local key_str = tostring(k)
		if type(v) == "table" then
			ui_handler:add_text_to_ui_by_name("terminal", (string.rep("  ", indent) .. key_str .. " = {"))
			print(string.rep("  ", indent) .. key_str .. " = {")
			deep_print(v, indent + 1, visited)
			ui_handler:add_text_to_ui_by_name("terminal", (string.rep("  ", indent) .. "}"))
			print((string.rep("  ", indent) .. "}"))
		else
			ui_handler:add_text_to_ui_by_name("terminal", (string.rep("  ", indent) .. key_str .. " = " .. tostring(v)))
			print((string.rep("  ", indent) .. key_str .. " = " .. tostring(v)))
		end
	end
end

function love.load()
	config:load()

	render_handler:load()
	love.graphics.setDefaultFilter("nearest", "nearest")
	love.window.setTitle(game_cfg.window.title)
	love.window.setMode(0, 0, {
		resizable = game_cfg.window.resizable,
		vsync = game_cfg.window.vsync,
		fullscreen = game_cfg.window.fullscreen,
	})

	local map_max_x = game_cfg.map.max_x
	local map_max_y = game_cfg.map.max_y
	local map_max_z = game_cfg.map.max_z
	local map_min_z = game_cfg.map.min_z

	local player = {
		chars = { "@" },
		x = 20,
		y = 20,
		z = 1,
		color = { 0.8, 0.8, 0.9, 1 },
		effect_color = { 0.45, 0.45, 0.5, 0.5 },
		name = "Player",
		tags = { blocks = true, attackable = true },
		default_action = "attackable",
		allowed_actions = {
			attackable = true,
			moveable = true,
			interactable = true,
		},
		stats = {
			health = { health = 20, max_health = 20 },
			stamina = { stamina = 10, max_stamina = 10 },
			hunger = { hunger = 10, max_hunger = 10 },
			sight = { sight = 30, max_sight = 30 },
		},
		inventory = {
			sword = { name = "sword" },
			armor = { name = "armor" },
			usable_item_dummy = { name = "usable_dummy" },
			dummy_item = { name = "dummy" },
		},
		damage = 2,
	}

	input_handler:set_actor(player)
	entities:set_player(player)
	entities:add_from_template("vampire", 5, 5, 1)
	entities:add_from_template("vampire", 8, 6, 1)
	entities:add_from_template("crate", 10, 10, 1)
	entities:add_from_template("barricade", 15, 14, 1)

	map:load(map_max_x, map_max_y, map_max_z, map_min_z, "town")
	map:update_visibility(entities.player.x, entities.player.y, entities.player.stats.sight.sight)

	ui_handler:load()
	ui_handler:update_status(entities.player)
	render_handler:load(entities.player.x, entities.player.y)
end

function love.update(dt) --TODO some of this should maybe live in a turn handler module
	if input_handler:update(dt) then
		map:update_visibility(entities.player.x, entities.player.y, entities.player.stats.sight.sight)
		ai_handler:process_turn()
		ui_handler:update_status(entities.player)
	end
	render_handler:update(entities.player.x, entities.player.y, dt)
	visuals:update(dt)
end

function love.draw()
	render_handler:draw()
	visualizer:draw()
end
