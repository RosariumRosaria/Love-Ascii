local render_cfg = require("config.render_config")
local config = {}

function config:load2()
	local scale = render_cfg.font_scale
	self.font = love.graphics.newFont(render_cfg.font_base_size * scale)
	self.small_font = love.graphics.newFont(render_cfg.font_base_size)
	love.graphics.setFont(self.font)
	self.tile_size = self.font:getHeight()
	self.small_tile_size = self.tile_size / scale
end

function config:load()
	local scale = render_cfg.font_scale
	local font_path = "/assets/fonts/PressStart2P-Regular.ttf"
	self.font = love.graphics.newFont(font_path, render_cfg.font_base_size * scale)
	self.small_font = love.graphics.newFont(font_path, render_cfg.font_base_size)
	self.font:setFilter("nearest", "nearest")
	self.small_font:setFilter("nearest", "nearest")
	love.graphics.setFont(self.font)
	self.tile_size = self.font:getHeight()
	self.small_tile_size = self.tile_size / scale
end

return config
