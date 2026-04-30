local render_cfg = require("config.render_config")
local config = {}

function config:load()
	local scale = render_cfg.font_scale
	self.font = love.graphics.newFont(render_cfg.font_base_size * scale)
	self.small_font = love.graphics.newFont(render_cfg.font_base_size)
	love.graphics.setFont(self.font)
	self.tile_size = self.font:getHeight()
	self.small_tile_size = self.tile_size / scale
end

return config
