-- Prefab loader — the single sanctioned game-side change for the map maker tool
-- (tools/mapmaker). Reads a prefab file (see its format in tools/mapmaker/prefab_io.lua),
-- overwrites the covered cells at an offset, spawns listed entities, and returns the
-- player start if the prefab defines one. Inert unless something calls it — gated in
-- main.lua on a config.game_config.prefab entry that is absent by default.
--
-- Tiles are shared template references (never deep-copied), so stamping is
-- `tiles[y][x][z] = types[name]`. Unknown tile/entity names fail loud with position.

local types = require("map.tile_types")
local map = require("map.map")
local entities = require("entities.entities")

local prefab = {}

-- Records the last stamp so a debug reload can undo spawned entities before re-stamping.
prefab.last = nil

--------------------------------------------------------------------------------
-- parse (pure)
--------------------------------------------------------------------------------

local function split_commas(s)
	local out, i = {}, 1
	while true do
		local j = s:find(",", i, true)
		if j then
			out[#out + 1] = s:sub(i, j - 1)
			i = j + 1
		else
			out[#out + 1] = s:sub(i)
			return out
		end
	end
end

function prefab.parse(text)
	local data = { width = 0, height = 0, player = nil, tiles = {}, entities = {} }
	local lines = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		lines[#lines + 1] = line
	end

	local i = 1
	while i <= #lines do
		local t = lines[i]:match("^%s*(.-)%s*$")
		if t == "" or t:sub(1, 1) == "#" or t:match("^prefab") then
			i = i + 1
		elseif t:match("^size") then
			local w, h = t:match("^size%s+(%d+)%s+(%d+)")
			data.width, data.height = tonumber(w), tonumber(h)
			i = i + 1
		elseif t:match("^player") then
			local x, y, z = t:match("^player%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)")
			data.player = { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
			i = i + 1
		elseif t:match("^entity") then
			local name, x, y, z = t:match("^entity%s+(%S+)%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)")
			data.entities[#data.entities + 1] = { name = name, x = tonumber(x), y = tonumber(y), z = tonumber(z) }
			i = i + 1
		elseif t:match("^layer") then
			local z = tonumber(t:match("^layer%s+(%-?%d+)"))
			local layer = {}
			data.tiles[z] = layer
			for y = 1, data.height do
				local tokens = split_commas(lines[i + y] or "")
				local row = {}
				for x = 1, data.width do
					if tokens[x] and tokens[x] ~= "" then
						row[x] = tokens[x]
					end
				end
				layer[y] = row
			end
			i = i + data.height + 1
		else
			i = i + 1
		end
	end

	return data
end

--------------------------------------------------------------------------------
-- file reading (repo prefabs/ first, then the tool's LÖVE save dir)
--------------------------------------------------------------------------------

local function read_file(filename)
	-- The game's source dir is the repo, so prefabs/ is readable via love.filesystem.
	if love and love.filesystem and love.filesystem.getInfo("prefabs/" .. filename) then
		return love.filesystem.read("prefabs/" .. filename)
	end
	-- Fallback: the map maker's own Flatpak save dir (used when no repo-write override).
	local home = os.getenv("HOME") or ""
	local candidates = {
		home .. "/.var/app/org.love2d.love2d/data/love/love-ascii-mapmaker/" .. filename,
		home .. "/.local/share/love/love-ascii-mapmaker/" .. filename,
	}
	for _, path in ipairs(candidates) do
		local f = io.open(path, "r")
		if f then
			local text = f:read("*a")
			f:close()
			return text
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- stamp
--------------------------------------------------------------------------------

-- Removes entities spawned by the previous stamp (for the debug reload path).
function prefab.clear_last()
	if not prefab.last then
		return
	end
	for _, e in ipairs(prefab.last.spawned) do
		entities.remove(e)
	end
	prefab.last = nil
end

-- Stamp `filename` with its top-left cell at map coords (ox, oy). Returns the player
-- start table {x,y,z} in map coords if the prefab defines one, else nil.
function prefab.stamp(filename, ox, oy)
	ox = ox or 1
	oy = oy or 1
	local text = read_file(filename)
	if not text then
		error("prefab: could not read '" .. tostring(filename) .. "'")
	end
	local data = prefab.parse(text)
	local tiles = map:get_tiles()
	local spawned = {}

	for z, layer in pairs(data.tiles) do
		for y = 1, data.height do
			local row = layer[y]
			if row then
				for x = 1, data.width do
					local name = row[x]
					if name then
						local mx, my = ox + x - 1, oy + y - 1
						if not types[name] then
							error(
								string.format(
									"prefab '%s': unknown tile '%s' at layer %d cell (%d,%d)",
									filename,
									name,
									z,
									x,
									y
								)
							)
						end
						if map:in_bounds(mx, my) then
							tiles[my][mx][z] = types[name] -- reference, never mutate in place
						end
					end
				end
			end
		end
	end

	for _, e in ipairs(data.entities) do
		local mx, my = ox + e.x - 1, oy + e.y - 1
		if map:in_bounds(mx, my) then
			-- add_from_template errors loud on an unknown name.
			spawned[#spawned + 1] = entities.add_from_template(e.name, mx, my, e.z)
		end
	end

	prefab.last = { filename = filename, ox = ox, oy = oy, spawned = spawned }

	if data.player then
		return { x = ox + data.player.x - 1, y = oy + data.player.y - 1, z = data.player.z }
	end
	return nil
end

return prefab
