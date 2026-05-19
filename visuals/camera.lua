local render_cfg = require("config.render_config")

local camera = {}

local x = nil
local y = nil
local speed = render_cfg.camera_speed

function camera:load(player_x, player_y)
	x = player_x
	y = player_y
end

function camera:update(target_x, target_y, dt)
	x = x + (target_x - x) * speed * dt
	y = y + (target_y - y) * speed * dt
end

function camera:get_position()
	return x, y
end

return camera
