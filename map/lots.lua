local gen_cfg = require("config.generation_config")

local lots = {}

function lots.subdivide(rect, depth, lots_list, road_list)
	if depth == 0 then
		table.insert(lots_list, rect)
		return
	end
	local vertical = rect.w >= rect.h

	local cut = vertical and rect.w or rect.h

	local chance = math.random()
	local road_width = math.max(0, math.floor(depth / 2) - 1)

	if
		cut < gen_cfg.lot_min_size * 2 + road_width
		or (chance > gen_cfg.lot_stop_chance and cut < gen_cfg.lot_max_size)
	then
		table.insert(lots_list, rect)
		return
	end

	local a, b
	local frac = 0.3 + (0.1 * math.random(3))

	if vertical then
		local sx = math.floor(rect.w * frac)
		a = { x = rect.x, y = rect.y, w = sx, h = rect.h }
		b = { x = rect.x + sx + road_width, y = rect.y, w = rect.w - sx - road_width, h = rect.h }

		if road_width > 0 then
			table.insert(road_list, { x = rect.x + sx, y = rect.y, w = road_width, h = rect.h, depth = depth })
		end
	else
		local sy = math.floor(rect.h * frac)
		a = { x = rect.x, y = rect.y, w = rect.w, h = sy }
		b = { x = rect.x, y = rect.y + sy + road_width, w = rect.w, h = rect.h - sy - road_width }
		if road_width > 0 then
			table.insert(road_list, { x = rect.x, y = rect.y + sy, w = rect.w, h = road_width, depth = depth })
		end
	end
	lots.subdivide(a, depth - 1, lots_list, road_list)
	lots.subdivide(b, depth - 1, lots_list, road_list)
end

return lots
