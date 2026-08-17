local config = require("src.config.runtime")
local render_utils = require("src.visuals.render.utils")
local utils = require("src.utils")
local small_tile_size
local small_font
local very_small_tile_size
local very_small_font
local medium_tile_size
local medium_font
local big_tile_size
local big_font
local very_big_tile_size
local very_big_font

local panels = {
	panel_list = {},
}

local FONTS = {}

function panels:reset()
	self.panel_list = {}
end

local function to_entry(value)
	if type(value) == "string" then
		return { text = value, alpha = 1 }
	elseif type(value) == "table" then
		assert(value.text)
		value.alpha = value.alpha or 1
		return value
	else
		assert(false, "Invalid entry type: " .. type(value))
	end
end

function panels:add_text_to_panel(panel, text)
	if not panel then
		return false
	end
	table.insert(panel.texts, to_entry(text))

	if #panel.texts > panel.capacity then
		table.remove(panel.texts, 1)
	end
end

function panels:set_panel_text(panel, list)
	if not panel then
		return false
	end
	panel.texts = {}
	for _, value in ipairs(list) do
		self:add_text_to_panel(panel, value)
	end
end

function panels:get_panel_list()
	return self.panel_list
end

local function slice_runs(colored, s, e)
	local out = {}
	local run_start = 1
	for i = 1, #colored, 2 do
		local color = colored[i]
		local str = colored[i + 1]
		local run_end = run_start + #str - 1
		local a = math.max(run_start, s)
		local b = math.min(run_end, e)
		if a <= b then
			table.insert(out, color)
			table.insert(out, str:sub(a - run_start + 1, b - run_start + 1))
		end
		run_start = run_end + 1
	end
	return out
end

local function split_colored(colored, plain, lines)
	local out = {}
	local pos = 1
	for _, line in ipairs(lines) do
		if #line == 0 then
			table.insert(out, false)
		else
			local s = plain:find(line, pos, true)
			local e = s + #line - 1
			table.insert(out, slice_runs(colored, s, e))
			pos = e + 1
		end
	end
	return out
end

local BASE_TEXT_INSET_X = 2

function panels:get_text_inset_x(panel)
	return BASE_TEXT_INSET_X + (panel.text_offset_x or 0)
end

function panels:get_visible_texts(panel)
	local font = panel.font or small_font
	local tile_size = panel.tile_size or small_tile_size
	local wrap_width = math.max(1, panel.width - self:get_text_inset_x(panel) * 2)
	local wrapped = {}
	for _, entry in ipairs(panel.texts) do
		local text = entry.text
		local _, lines = font:getWrap(text, wrap_width)
		if #lines == 0 then
			table.insert(wrapped, { text = "", alpha = entry.alpha })
		else
			local colored_lines = entry.colored and split_colored(entry.colored, entry.text, lines)
			for j, l in ipairs(lines) do
				table.insert(wrapped, {
					text = l,
					colored = colored_lines and colored_lines[j],
					alpha = entry.alpha,
					row_index = entry.row_index,
				})
			end
		end
	end

	local max_lines = math.floor(panel.height / tile_size)
	local total_lines = #wrapped

	panel.scroll_offset = math.max(0, math.min(panel.scroll_offset, math.max(0, total_lines - max_lines)))

	local start_line = math.max(1, total_lines - panel.scroll_offset - max_lines + 1)
	local end_line = math.min(total_lines, start_line + max_lines - 1)

	local visible_texts = {}
	for i = start_line, end_line do
		table.insert(visible_texts, wrapped[i])
	end
	return visible_texts
end

function panels:add_panel(name, opts)
	opts = opts or {}

	local screen_width = love.graphics.getWidth()
	local screen_height = love.graphics.getHeight()

	local font = small_font
	local tile_size = small_tile_size

	if opts.font then
		font = FONTS[opts.font].font
		tile_size = FONTS[opts.font].tile
	end

	local width = opts.width or (screen_width / 6)
	local height = opts.height or (screen_height / 6)

	local panel = {
		x = opts.x or 0,
		y = opts.y or 0,
		height = height,
		width = width,
		name = name,
		color = opts.color or { 0, 0, 0, 0.5 },
		outline_width = opts.outline_width or (screen_width / 800),
		outline_color = opts.outline_color or { 1, 1, 1, 0.5 },
		texts = {},
		center_text = opts.center_text or false,
		tile_grid = opts.tile_grid,
		scroll_offset = 0,
		offset_y = (opts.offset_y or 1.5),
		font = font,
		tile_size = tile_size,
		visible = true,
		auto_size = opts.auto_size or false,
		center_vertical = opts.center_vertical or opts.auto_size or false,
		screen_anchor = opts.screen_anchor,
		capacity = math.floor(height / tile_size) * 10,
		text_offset_x = opts.text_offset_x or 0,
		text_offset_y = opts.text_offset_y or 0,
	}

	local idx = self:find_index(name)
	if idx then
		self.panel_list[idx] = panel
	else
		table.insert(self.panel_list, panel)
	end

	return panel
end

function panels:find_index(name)
	for i, panel in ipairs(self.panel_list) do
		if panel.name == name then
			return i
		end
	end
end

function panels:get_panel(name)
	local idx = self:find_index(name)
	if idx then
		return self.panel_list[idx]
	end
end

function panels:remove_panel(name)
	local idx = self:find_index(name)
	if idx then
		table.remove(self.panel_list, idx)
	end
end

function panels:mouse_in(panel, mx, my)
	return panel
		and panel.screen_y
		and panel.screen_x
		and panel.top
		and panel.visible_texts
		and utils.point_in_rect(mx, my, panel.screen_x, panel.screen_y, panel.width, panel.height)
end

function panels:row_at(panel, mx, my)
	if not self:mouse_in(panel, mx, my) then
		return
	end
	local i = math.floor((my - panel.screen_y - panel.top) / (panel.tile_size or small_tile_size)) + 1
	if not panel.visible_texts[i] then
		return
	end
	return panel.visible_texts[i].row_index
end

function panels:add_text_to_panel_by_name(name, text)
	self:add_text_to_panel(self:get_panel(name), text)
end

function panels:set_panel_text_by_name(name, list)
	self:set_panel_text(self:get_panel(name), list)
end

function panels:clear_panel_by_name(name)
	local panel = self:get_panel(name)
	if not panel then
		return
	end
	panel.texts = {}
end

function panels:reload_fonts()
	small_tile_size = config.small_tile_size
	small_font = config.small_font
	very_small_tile_size = config.terminal_tile_size
	very_small_font = config.terminal_font
	medium_tile_size = config.medium_tile_size
	medium_font = config.medium_font
	big_tile_size = config.big_tile_size
	big_font = config.big_font
	very_big_tile_size = config.very_big_tile_size
	very_big_font = config.very_big_font
	FONTS = {
		very_small = { font = very_small_font, tile = very_small_tile_size },
		small = { font = small_font, tile = small_tile_size },
		medium = { font = medium_font, tile = medium_tile_size },
		big = { font = big_font, tile = big_tile_size },
		very_big = { font = very_big_font, tile = very_big_tile_size },
	}
end

function panels:measure_auto_size(panel)
	local line_height = panel.tile_size or small_tile_size
	local outline = panel.outline_width or 1
	local pad_x = outline + line_height * 0.25
	local pad_y = line_height * 0.2
	panel.width = render_utils.get_max_text_width(panel.texts, panel.font) + pad_x * 2
	panel.height = #panel.texts * line_height + pad_y * 2
end

return panels
