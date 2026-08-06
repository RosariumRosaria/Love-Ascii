local config = require("src.config.runtime")
local render_cfg = require("src.config.render_config")

local camera = {}

local x = nil
local y = nil
local speed = render_cfg.camera.speed
local dead_zone = 0

local function approach(current, target, decay)
	if math.abs(target - current) < dead_zone then
		return current
	end
	return target + (current - target) * decay
end

function camera:reload_fonts()
	dead_zone = render_cfg.camera.dead_zone / config.tile_size
end

function camera:load(player_x, player_y)
	x = player_x
	y = player_y
end

function camera:update(target_x, target_y, dt)
	local decay = math.exp(-speed * dt)
	x = approach(x, target_x, decay)
	y = approach(y, target_y, decay)
end

function camera:get_position()
	return x, y
end

return camera
