local gen_cfg = require("src.config.generation_config")
local utils = require("src.utils")

local lots = {}

function lots.partition(rect, count, border_width, vertical)
	local wards = {}
	local borders = {}
	local remaining = rect
	local border_count = count - 1
	local width = (vertical and rect.w) or rect.h
	local ward_width = math.floor((width - (border_count * border_width)) / count)
	for _ = 1, border_count do
		local ward, border
		ward, remaining, border = utils.split_rect(remaining, vertical, ward_width, border_width)
		table.insert(wards, ward)
		table.insert(borders, border)
	end
	table.insert(wards, remaining)
	return wards, borders
end

function lots.subdivide(rect, depth, lots_list, road_list)
	if depth == 0 then
		table.insert(lots_list, rect)
		return
	end
	local vertical = rect.w >= rect.h

	local cut = vertical and rect.w or rect.h

	local chance = love.math.random()
	local road_width = math.max(0, math.floor(depth / 2) - 1)

	if
		cut < gen_cfg.lots.min_size * 2 + road_width
		or (chance < gen_cfg.lots.stop_chance and cut < gen_cfg.lots.max_size)
	then
		table.insert(lots_list, rect)
		return
	end
	local frac = 0.3 + (0.1 * love.math.random(3))
	local offset = utils.clamp(math.floor(cut * frac), gen_cfg.lots.min_size, cut - gen_cfg.lots.min_size - road_width)

	local a, b, road = utils.split_rect(rect, vertical, offset, road_width)

	if road then
		road.depth = depth
		table.insert(road_list, road)
	end

	lots.subdivide(a, depth - 1, lots_list, road_list)
	lots.subdivide(b, depth - 1, lots_list, road_list)
end

return lots
