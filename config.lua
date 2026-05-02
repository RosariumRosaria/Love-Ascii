local render_cfg = require("config.render_config")
local game_cfg = require("config.game_config")
local config = {}

function config:load()
	local scale = render_cfg.font_scale
	if render_cfg.use_pixel_font then
		local font_path = "/assets/fonts/PressStart2P-Regular.ttf"
		self.font = love.graphics.newFont(font_path, render_cfg.font_base_size * scale)
		self.small_font = love.graphics.newFont(font_path, render_cfg.font_base_size)
		self.font:setFilter("nearest", "nearest")
		self.small_font:setFilter("nearest", "nearest")
	else
		self.font = love.graphics.newFont(render_cfg.font_base_size * scale)
		self.small_font = love.graphics.newFont(render_cfg.font_base_size)
	end
	love.graphics.setFont(self.font)
	self.tile_size = self.font:getHeight()
	self.small_tile_size = self.tile_size / scale
end

function config:toggle_font()
	render_cfg.use_pixel_font = not render_cfg.use_pixel_font
	self:load()
end

function config:setup_window()
	love.graphics.setDefaultFilter("nearest", "nearest")
	love.window.setTitle(game_cfg.window.title)
	love.window.setMode(0, 0, {
		resizable = game_cfg.window.resizable,
		vsync = game_cfg.window.vsync,
		fullscreen = game_cfg.window.fullscreen,
		borderless = game_cfg.window.borderless,
	})
end

return config
