local config = require("config")
local map = require("map.map")
local render_handler = require("visuals.render_handler")
local visuals = require("visuals.visuals")
local ui_handler = require("visuals.ui_handler")
local input_handler = require("engine.input_handler")
local fov_handler = require("fov.fov_handler")
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
      ui_handler:addTextToUIByName("terminal", (string.rep("  ", indent) .. keyStr .. " = {"))
      print(string.rep("  ", indent) .. keyStr .. " = {")
      deepPrint(v, indent + 1, visited)
      ui_handler:addTextToUIByName("terminal", (string.rep("  ", indent) .. "}"))
      print((string.rep("  ", indent) .. "}"))
    else
      ui_handler:addTextToUIByName("terminal", (string.rep("  ", indent) .. keyStr .. " = " .. tostring(v)))
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

  local mapWidth = 200
  local mapHeight = 200
  local mapDepth = 7

  player = { --TODO, why is this global
    chars = { "@" },
    x = 20,
    y = 20,
    z = 1,
    tags = { blocks = true },
    stats = {
      health = { health = 10, maxHealth = 10 },
      stamina = { stamina = 10, maxStamina = 10 },
      hunger = { hunger = 10, maxHunger = 10 },
    },
    inventory = {
      sword = { name = "sword" },
      armor = { name = "armor" },
      usableItemDummy = { name = "usableDum" },
      dummyItem = { name = "dummy" },
    },
    damage = 1,
  }

  entities:addEntity(player)
  entities:addFromTemplate("vampire", 5, 5, 1)
  entities:addFromTemplate("crate", 6, 5, 1)
  entities:addFromTemplate("barricade", 7, 5, 1)

  map:load(mapWidth, mapHeight, mapDepth, "town")
  map:updateVisibility(player.x, player.y, 25)

  ui_handler:load()
end

function love.update(dt) --Todo: Make movement check key pressed, to avoid the timer
  input_handler:update(dt)
  visuals:update(dt)
end

function love.draw()
  render_handler:draw(player.x, player.y)
end
