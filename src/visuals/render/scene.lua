local effects = require("src.visuals.effects.effects")
local panels = require("src.visuals.ui.panels")
local entities = require("src.sim.entities")
local animation = require("src.visuals.render.animation")
local render_utils = require("src.visuals.render.utils")
local map = require("src.map.map")
local render_primitives = require("src.visuals.render.primitives")
local render_cfg = require("src.config.render_config")
local camera = require("src.visuals.camera")
local painter = require("src.visuals.render.painter")
local draw_buffer = require("src.visuals.render.draw_buffer")
local particles = require("src.visuals.particles.particles")
local debug_panel = require("src.debug.debug_panel")

local scene = {}

local POST_SHADER = [[
	extern number strength;
	extern number radius;
	extern number softness;
	extern number gamma;

	vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
		vec4 px = Texel(tex, uv);
		number d = distance(uv, vec2(0.5, 0.5));
		number v = smoothstep(radius, radius + softness, d);
		px.rgb = pow(px.rgb, vec3(gamma));
		px.rgb *= 1.0 - v * strength;
		return px * color;
	}
]]

function scene:_ensure_canvas()
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	if self.world_canvas then
		local cw, ch = self.world_canvas:getDimensions()
		if cw == w and ch == h then
			return
		end
	end
	self.world_canvas = love.graphics.newCanvas(w, h)
end

function scene:_build_post_shader()
	local cfg = render_cfg.vignette
	local strength = (cfg.enabled and cfg.strength) or 0

	self.vignette_shader = love.graphics.newShader(POST_SHADER)
	self.vignette_shader:send("strength", strength)
	self.vignette_shader:send("radius", cfg.radius)
	self.vignette_shader:send("softness", cfg.softness)
end

function scene:resize()
	self:_ensure_canvas()
	-- TODO(resize-polish): re-anchor the HUD here. hud panels are built once in
	-- hud:load and never re-laid out, so a resolution change (e.g. the settings
	-- FULLSCREEN toggle) leaves them at the old anchor. Menus survive because
	-- flow calls menu:refresh after an adjust, but the HUD has no such path.
	-- TODO(resize-polish): panel/hud outline_width is baked from screen_width at
	-- creation (panels.lua / hud.lua) and isn't recomputed on resize, so outlines
	-- render at the old thickness after a resolution change. Cosmetic.a
	local draw_dist = render_cfg.camera.draw_distance
	local camera_x, camera_y = camera:get_position()

	local cx = math.floor(camera_x or 0)
	local cy = math.floor(camera_y or 0)
	local end_x = math.min(cx + draw_dist, map:get_max_x())
	local end_y = math.min(cy + draw_dist, map:get_max_y())
	local start_x = math.max(cx - draw_dist, 1)
	local start_y = math.max(cy - draw_dist, 1)
	local start_z = map.min_z
	local end_z = map.max_z
	local tiles = map:get_tiles()
	local visible_grid, explored_grid = map:get_visibility_grids()
	local time = love.timer.getTime()
	render_utils.refresh_frame_cache()
	self.vignette_shader:send("gamma", render_utils.get_gamma())
	draw_buffer:clear()

	for y = start_y, end_y do
		local vis_row = visible_grid[y]
		local exp_row = explored_grid[y]
		local tile_row = tiles[y]
		for x = start_x, end_x do
			local visible = vis_row[x]
			local explored = exp_row[x]
			if visible or explored then
				local stack = tile_row[x]
				local x_screen, y_screen = render_utils.get_screen_coords(x, y, camera_x, camera_y)
				local base = render_utils.distance_scale(x, y, camera_x, camera_y)
				local light_data = map:get_lighting_tile(x, y)
				for z = start_z, end_z do
					local tile = stack[z]
					if tile then
						painter:emit_tile_at_z(
							tile,
							x,
							y,
							z,
							camera_x,
							camera_y,
							visible,
							explored,
							time,
							x_screen,
							y_screen,
							base,
							light_data
						)
					end
				end
			end
		end
	end

	for _, entity in ipairs(entities.get_list()) do
		painter:emit_entity(
			entity,
			camera_x,
			camera_y,
			map:is_visible(entity.x, entity.y),
			map:is_explored(entity.x, entity.y),
			time
		)
	end

	for _, p in ipairs(particles:get_particles()) do
		painter:emit_particle(p, camera_x, camera_y, time)
	end

	for _, effect in ipairs(effects:get_effect_list()) do
		local ex, ey = math.floor(effect.x), math.floor(effect.y)
		painter:emit_effect(effect, camera_x, camera_y, map:is_visible(ex, ey))
	end

	draw_buffer:sort()

	love.graphics.setCanvas(self.world_canvas)
	love.graphics.clear(0, 0, 0, 1)
	draw_buffer:walk()
	love.graphics.setCanvas()

	love.graphics.setShader(self.vignette_shader)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.world_canvas, 0, 0)
	love.graphics.setShader()

	painter:draw_grid_overlay(start_x, start_y, end_x, end_y, camera_x, camera_y)
	debug_panel.draw(camera_x, camera_y)

	for _, panel in ipairs(panels:get_panel_list()) do
		painter:draw_panel(panel, camera_x, camera_y)
	end
end

function scene:reload_fonts()
	render_utils.load()
	render_primitives.load()
	panels:reload_fonts()
	painter:reload_fonts()
end

function scene:load(player_x, player_y)
	camera:load(player_x, player_y)
	local cx, cy = camera:get_position()
	particles:load(cx, cy)
	self:_ensure_canvas()
	self:_build_post_shader()
end

function scene:update(dt)
	animation.update(dt)
	local player = entities.player
	local pa = player.anim
	local tx = (pa and pa.tween_x) or player.x
	local ty = (pa and pa.tween_y) or player.y
	camera:update(tx, ty, dt)
	local cx, cy = camera:get_position()
	particles:update(dt, cx, cy)
end

return scene
