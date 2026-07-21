local debug_state = require("src.debug.debug_state")

local profiler = {
	mode = "3si1m1",
}

local ok, jit_p = pcall(require, "jit.p")

function profiler:toggle()
	if not ok then
		print("[profiler] jit.p not available: " .. tostring(jit_p))
		return
	end
	if debug_state.profiling then
		debug_state.profiling = false
		print("[profiler] stopped, report:")
		jit_p.stop()
	else
		debug_state.profiling = true
		jit_p.start(self.mode)
		print(string.format("[profiler] sampling (mode %q) - press f2 again for report", self.mode))
	end
end

return profiler
