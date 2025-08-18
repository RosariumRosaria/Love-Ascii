local engine = require("engine.engine")
local map = require("map.map")
local render_handler = require("visuals.render_handler")
local ui_handler = require("visuals.ui_handler")
local ai_handler = require("engine.ai_handler")
local voroni_generator = require("voroni.voroni_generator")
local input_handler = {}

local time_since_last_turn = 0
local time_between_turns = 0.125
local last_turn = { x = 0, y = 0 }
local grabbed = nil

local direction_keys = {}
local key_to_dir = {
  left = { x = -1, y = 0 },
  right = { x = 1, y = 0 },
  up = { x = 0, y = -1 },
  down = { x = 0, y = 1 },
}

function love:keypressed(key)
  if key_to_dir[key] then
    for i, v in ipairs(direction_keys) do
      if v == key then
        table.remove(direction_keys, i)
        break
      end
    end
    table.insert(direction_keys, key)
  end
end

function love:keyreleased(key)
  if key_to_dir[key] then
    for i, v in ipairs(direction_keys) do
      if v == key then
        table.remove(direction_keys, i)
        break
      end
    end
  end
end

function input_handler:update(dt, player_dead)
  time_since_last_turn = time_since_last_turn + dt
  if time_since_last_turn < time_between_turns then
    return
  end
  time_since_last_turn = 0
  local took_action = false
  local move_dir = { x = 0, y = 0 }
  local last_key = direction_keys[#direction_keys]
  if last_key and key_to_dir[last_key] then
    move_dir = key_to_dir[last_key]
  end

  local is_moving = move_dir.x ~= 0 or move_dir.y ~= 0
  local has_moved = last_turn.x ~= 0 or last_turn.y ~= 0
  if not player_dead then
    if is_moving or has_moved then
      if not is_moving then
        move_dir = last_turn
      end
      if love.keyboard.isDown("f") then
        took_action = engine:attack(player, move_dir.x, move_dir.y)
      elseif love.keyboard.isDown("e") then
        took_action = engine:interact(player, move_dir.x, move_dir.y)
        if not took_action then
          took_action = engine:interact(player, -1 * move_dir.x, -1 * move_dir.y)
          --TODO should this be in input handler? Also investigate double priting
        end
      elseif love.keyboard.isDown("r") then
        engine:inspect(player, move_dir.x, move_dir.y)
      elseif is_moving then
        if love.keyboard.isDown("q") then
          if not grabbed then
            grabbed = engine:grab(player, move_dir.x, move_dir.y) or grabbed
          end
          if grabbed then
            if player.x == grabbed.x + move_dir.x and player.y == grabbed.y + move_dir.y then
              took_action = engine:pull(player, move_dir.x, move_dir.y)
            elseif player.x + move_dir.x == grabbed.x and player.y + move_dir.y == grabbed.y then
              took_action = engine:push(player, move_dir.x, move_dir.y)
            end
          end
        else
          grabbed = false
          took_action = engine:move(player, move_dir.x, move_dir.y)
        end
      end
      map:update_visibility(player.x, player.y, 30) --TODO, why do you live in input handler? And magic number...
      last_turn = move_dir
    end
  end

  if love.keyboard.isDown("z") then
    render_handler:switch_offset()
    voroni_generator:reload(125)
  end

  if love.keyboard.isDown("x") then
    ui_handler:switch_status()
    voroni_generator:lloyd()
  end

  if love.keyboard.isDown("escape") then
    love.event.quit()
  end

  if took_action then
    ai_handler:process_turn()
    ui_handler:update_status()
  end
end

function love.wheelmoved(_, y)
  local term = ui_handler:get_ui("terminal")
  if term then
    term.scroll_offset = math.max(0, term.scroll_offset - y)
  end
end

return input_handler
