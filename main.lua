local config = require("config")
local map = require("map.map")
local render_handler = require("visuals.render_handler")
local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local input_handler = require("engine.input_handler")
local visualizer = require("voroni.visualizer")
local entities = require("entities.entities")

_G.deepPrint = function(tbl, indent, visited) --TODO Gross, for debug
  indent = indent or 0
  visited = visited or {}

  if visited[tbl] then
    print(string.rep("  ", indent) .. "*recursive reference*")
    return
  end
  visited[tbl] = true

  for k, v in pairs(tbl) do
    local keyStr = tostring(k)
    if type(v) == "table" then
      ui_handler:add_text_to_ui_by_name("terminal", (string.rep("  ", indent) .. keyStr .. " = {"))
      print(string.rep("  ", indent) .. keyStr .. " = {")
      deepPrint(v, indent + 1, visited)
      ui_handler:add_text_to_ui_by_name("terminal", (string.rep("  ", indent) .. "}"))
      print((string.rep("  ", indent) .. "}"))
    else
      ui_handler:add_text_to_ui_by_name("terminal", (string.rep("  ", indent) .. keyStr .. " = " .. tostring(v)))
      print((string.rep("  ", indent) .. keyStr .. " = " .. tostring(v)))
    end
  end
end

function love.load()
  config:load()

  render_handler:load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.window.setTitle("Hello World")
  love.window.setMode(0, 0, { resizable = true, vsync = true, fullscreen = true })

  local mapWidth = 500
  local mapHeight = 500
  local mapDepth = 7

  player = { --TODO, why is this global
    chars = { "@" },
    x = 220,
    y = 220,
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
      health = { health = 20, maxHealth = 20 },
      stamina = { stamina = 10, maxStamina = 10 },
      hunger = { hunger = 10, maxHunger = 10 },
    },
    inventory = {
      sword = { name = "sword" },
      armor = { name = "armor" },
      usableItemDummy = { name = "usableDum" },
      dummyItem = { name = "dummy" },
    },
    damage = 2,
  }

  entities:add_entity(player)
  entities:add_from_template("vampire", 5, 5, 1)
  entities:add_from_template("vampire", 8, 6, 1)
  entities:add_from_template("vampire", 9, 11, 1)
  entities:add_from_template("vampire", 9, 6, 1)
  entities:add_from_template("crate", 10, 10, 1)
  entities:add_from_template("barricade", 15, 14, 1)

  map:load(mapWidth, mapHeight, mapDepth, "town")
  map:update_visibility(player.x, player.y, 25)

  ui_handler:load()
  ui_handler:update_status()
end

function love.update(dt) --Todo: Make movement check key pressed, to avoid the timer
  input_handler:update(dt, player.dead)

  visuals:update(dt)
end

function love.draw()
  render_handler:draw(player.x, player.y)
  visualizer:draw()
end
