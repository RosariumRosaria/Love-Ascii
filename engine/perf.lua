local game_cfg = require("config.game_config")
local debug_state = require("debug.debug_state")
local config = require("config.runtime")

local perf = {
	frame_start = 0,
	frame_count = 0,
	last_warn_time = -math.huge,
}

function perf:begin_frame()
	self.frame_start = love.timer.getTime()
end

function perf:draw()
	if not debug_state.show_perf then
		return
	end
	local font = config.small_font
	if not font then
		return
	end
	local prev_font = love.graphics.getFont()
	love.graphics.setFont(font)
	local r, g, b, a = love.graphics.getColor()
	local pad = 10
	local line = string.format("FPS: %d", love.timer.getFPS())
	local line_h = font:getHeight()
	local width = font:getWidth(line) + pad * 2
	local height = line_h + pad * 2
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", 0, 0, width, height)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(line, pad, pad)
	love.graphics.setColor(r, g, b, a)
	love.graphics.setFont(prev_font)
end

function perf:end_frame(ui)
	local now = love.timer.getTime()
	local elapsed = now - self.frame_start
	self.frame_count = self.frame_count + 1

	local cfg = game_cfg.perf
	if self.frame_count <= cfg.warmup_frames then
		return
	end
	if elapsed <= cfg.lag_warn_threshold then
		return
	end
	if now - self.last_warn_time < cfg.warn_cooldown then
		return
	end

	self.last_warn_time = now
	local msg = string.format("[lag] frame %.3fs > %.3fs", elapsed, cfg.lag_warn_threshold)
	print(msg)
	if ui then
		ui:add_text_to_ui_by_name("terminal", msg)
	end
end

return perf
