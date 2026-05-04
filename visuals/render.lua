local visuals = require("visuals.effects")
local ui_handler = require("visuals.ui")
local entities = require("entities.entities")
local render_utils = require("visuals.render_utils")
local map = require("map.map")
local render_primitives = require("visuals.render_primitives")
local render_cfg = require("config.render_config")
local camera = require("visuals.camera")
local scene_drawer = require("visuals.scene_drawer")

local render_handler = {}

function render_handler:draw()
	local draw_dist = render_cfg.draw_distance
	local camera_x, camera_y = camera:get_position()

	--Draw Map
	local cx = math.floor(camera_x or 0)
	local cy = math.floor(camera_y or 0)
	local end_x = math.min(cx + draw_dist, map:get_max_x())
	local end_y = math.min(cy + draw_dist, map:get_max_y())
	local start_x = math.max(cx - draw_dist, 1)
	local start_y = math.max(cy - draw_dist, 1)
	local tiles = map:get_tiles()
	-- Pass 1: underground
	for y = start_y, end_y do
		for x = start_x, end_x do
			scene_drawer:draw_tile(
				tiles[y][x],
				x,
				y,
				camera_x,
				camera_y,
				map:is_visible(x, y),
				map:is_explored(x, y),
				map.min_z,
				0
			)
		end
	end

	-- Pass 2: ground
	for y = start_y, end_y do
		for x = start_x, end_x do
			scene_drawer:draw_tile(tiles[y][x], x, y, camera_x, camera_y, map:is_visible(x, y), map:is_explored(x, y), 1, 1)
		end
	end

	--Draw Entities
	for _, entity in ipairs(entities:get_entity_list()) do
		scene_drawer:draw_entity(
			entity,
			camera_x,
			camera_y,
			map:is_visible(entity.x, entity.y),
			map:is_explored(entity.x, entity.y)
		)
	end

	-- Pass 3: above ground
	for y = start_y, end_y do
		for x = start_x, end_x do
			scene_drawer:draw_tile(
				tiles[y][x],
				x,
				y,
				camera_x,
				camera_y,
				map:is_visible(x, y),
				map:is_explored(x, y),
				2,
				map.max_z
			)
		end
	end

	scene_drawer:draw_grid_overlay(start_x, start_y, end_x, end_y, camera_x, camera_y)

	--Draw Visuals
	for _, visual in ipairs(visuals:get_visual_list()) do
		scene_drawer:draw_visual(visual, camera_x, camera_y, map:is_visible(visual.x, visual.y))
	end

	for _, ui in ipairs(ui_handler:get_ui_list()) do
		scene_drawer:draw_ui(ui)
	end
end

function render_handler:reload_fonts()
	render_utils.load()
	render_primitives.load()
	ui_handler:reload_fonts()
	scene_drawer:reload_fonts()
end

function render_handler:load(player_x, player_y)
	camera:load(player_x, player_y)
	scene_drawer:reload_settings()
end

function render_handler:update(target_x, target_y, dt)
	camera:update(target_x, target_y, dt)
end

return render_handler
