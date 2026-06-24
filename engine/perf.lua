local game_cfg = require("config.game_config")
local debug_state = require("debug.debug_state")
local config = require("config.runtime")
local time = require("engine.time")

local perf = {
	frame_start = 0,
	frame_count = 0,
	last_warn_time = -math.huge,
	worst_frame = nil,
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
	local lines = {
		string.format("FPS: %d", love.timer.getFPS()),
		string.format("Worst: %.1fms", (self.worst_frame and self.worst_frame.elapsed or 0) * 1000),
		string.format("Time: %s (%.2f)", time.part_of_day(), time.time_of_day()),
	}
	local line_h = font:getHeight()
	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, font:getWidth(l))
	end
	width = width + pad * 2
	local height = line_h * #lines + pad * 2
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", 0, 0, width, height)
	love.graphics.setColor(1, 1, 1, 1)
	for i, l in ipairs(lines) do
		love.graphics.print(l, pad, pad + line_h * (i - 1))
	end
	love.graphics.setColor(r, g, b, a)
	love.graphics.setFont(prev_font)
end

function perf:end_frame(panels)
	local now = love.timer.getTime()
	local elapsed = now - self.frame_start
	self.frame_count = self.frame_count + 1

	local cfg = game_cfg.perf
	if self.frame_count <= cfg.warmup_frames then
		return
	end

	if not self.window_start then
		self.window_start = now
	end

	if not self.worst_frame or elapsed > self.worst_frame.elapsed then
		self.worst_frame = { elapsed = elapsed, frame = self.frame_count }
	end

	if now - self.window_start >= cfg.worst_frame_window then
		self.worst_frame = nil
		self.window_start = now
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
	if panels then
		panels:add_text_to_panel_by_name("terminal", msg)
	end
end

return perf
