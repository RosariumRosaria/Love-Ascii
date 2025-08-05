local map = require("map.map")
local entities = require("entities.entities")

local pathfinder = {}

local function isTileFree(x, y, z, entityList, goal) --TODO, this and the similar function in engine should be moved
  if x == goal[1] and y == goal[2] and z == 1 then
    return true
  end

  if not map:walkable(x, y, z) then
    return false
  end

  for _, ent in ipairs(entityList) do
    if not entities:getTagEntity(ent, "walkable") and ent.x == x and ent.y == y and ent.z == z then
      return false
    end
  end

  return true
end

local function put(tab, node, priority)
  for i = 1, #tab do
    if tab[i][2] > priority then
      table.insert(tab, i, { node, priority })
      return
    end
  end
  table.insert(tab, { node, priority })
end

local function get(tab)
  local ret = tab[1]
  table.remove(tab, 1)
  return ret
end

local function getNeighbors(x, y, entityList, goal)
  local candidates = {
    { x + 1, y },
    { x - 1, y },
    { x, y + 1 },
    { x, y - 1 } --[[,
    { x + 1, y + 1 },
    { x - 1, y - 1 },
    { x + 1, y - 1 },
    { x - 1, y + 1 }, ]],
  }
  local neighbors = {}
  for _, pos in ipairs(candidates) do
    if isTileFree(pos[1], pos[2], 1, entityList, goal) then
      table.insert(neighbors, pos)
    end
  end
  return neighbors
end

local function heuristic(a, b)
  return math.abs(a[1] - b[1]) + math.abs(a[2] - b[2])
end

local function key(x, y)
  return x .. "," .. y
end

local function reconstructPath(came_from, start_key, goal_key) --TODO clean up gross key val conversion
  local current_key = goal_key
  local path = {}
  while current_key ~= start_key do
    local x, y = string.match(current_key, "(%-?%d+),(%-?%d+)")
    table.insert(path, 1, { tonumber(x), tonumber(y) })
    current_key = came_from[current_key]
    if not current_key then
      break
    end
  end
  local x, y = string.match(start_key, "(%-?%d+),(%-?%d+)")
  table.insert(path, 1, { tonumber(x), tonumber(y) })
  return path
end

function pathfinder:aStar(start, goal)
  local entityList = entities:getEntityList()

  local frontier = {}
  put(frontier, start, 0)
  local came_from = {}
  local cost_so_far = {}
  came_from[key(start[1], start[2])] = nil
  cost_so_far[key(start[1], start[2])] = 0
  local i = 1
  while #frontier > 0 do
    i = i + 1
    local node = get(frontier)
    local current = node[1]
    if current[1] == goal[1] and current[2] == goal[2] then
      break
    end
    for _, next in ipairs(getNeighbors(current[1], current[2], entityList, goal)) do
      local current_key = key(current[1], current[2])
      local next_key = key(next[1], next[2])
      local new_cost = cost_so_far[current_key] + 1 --TODO, add actual costs, as currently it doesn't exist
      if cost_so_far[next_key] == nil or new_cost < cost_so_far[next_key] then
        cost_so_far[next_key] = new_cost
        local priority = new_cost + heuristic(goal, next)
        put(frontier, next, priority)
        came_from[next_key] = current_key
      end
    end
  end

  local start_key = key(start[1], start[2])
  local goal_key = key(goal[1], goal[2])

  if not came_from[goal_key] then
    return nil
  end

  local path = reconstructPath(came_from, start_key, goal_key)
  if #path > 1 then
    return path[2]
  else
    return nil
  end
end

return pathfinder
