local game_cfg = require("config.game_config")

local perf = {
	frame_start = 0,
	frame_count = 0,
	last_warn_time = -math.huge,
}

function perf:begin_frame()
	self.frame_start = love.timer.getTime()
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
