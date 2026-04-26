local config = require("config")
local tileSize
local render_utils = require("visuals.render_utils")
local render_primitives = {}

function render_primitives.draw_rect(
	x_screen,
	y_screen,
	width,
	height,
	color,
	outlineWidth,
	outlineColor,
	roundedAmount
)
	local roundedAmountX = 0
	local roundedAmountY = 0

	if roundedAmount then
		roundedAmountX = width * roundedAmount
		roundedAmountY = height * roundedAmount
	end

	love.graphics.setColor(color)
	love.graphics.rectangle("fill", x_screen, y_screen, width, height, roundedAmountX, roundedAmountY)

	if outlineWidth and outlineColor then
		love.graphics.setLineWidth(outlineWidth)
		love.graphics.setColor(outlineColor)
		love.graphics.rectangle(
			"line",
			x_screen - outlineWidth,
			y_screen - outlineWidth,
			width + outlineWidth,
			height + outlineWidth,
			roundedAmountX,
			roundedAmountY
		)
		love.graphics.setLineWidth(1)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function render_primitives.draw_char(x_screen, y_screen, text, color, outlineColor, rotation, naturalRotation)
	if not text or text == "" then
		return
	end

	local font = love.graphics.getFont()
	local text_width = font:getWidth(text)

	local center_from_top = render_utils.getVisualCenterFromTop(font, text)

	local cx = x_screen + tileSize * 0.5
	local cy = y_screen + tileSize * 0.5

	local rads = math.rad(((rotation or 0) - (naturalRotation or 0)) % 360)

	local ox = text_width * 0.5
	local oy = center_from_top

	if outlineColor then
		love.graphics.setColor(outlineColor)
		love.graphics.print(text, cx + 1, cy + 1, rads, 1, 1, ox, oy)
	end

	love.graphics.setColor(color)
	love.graphics.print(text, cx, cy, rads, 1, 1, ox, oy)

	love.graphics.setColor(1, 1, 1, 1)
end

function render_primitives.drawTextBlock(texts, x_screen, y_screen, width, outline, center_text, color, lineHeight)
	local font = love.graphics.getFont()
	lineHeight = lineHeight or tileSize
	if color then
		love.graphics.setColor(color)
	end

	for i, text in ipairs(texts) do
		local dx = 0
		if center_text then
			dx = dx + (width - font:getWidth(text)) / 2
		end

		local drawX = x_screen + dx
		local drawY = y_screen + outline + ((i - 1) * lineHeight)

		love.graphics.print(text, drawX, drawY)
	end
end

function render_primitives.draw_panel(
	x_screen,
	y_screen,
	width,
	height,
	fillColor,
	outlineWidth,
	outlineColor,
	texts,
	centerText,
	textColor,
	lineHeight
)
	render_primitives.draw_rect(x_screen, y_screen, width, height, fillColor, outlineWidth, outlineColor)
	render_primitives.drawTextBlock(
		texts,
		x_screen,
		y_screen,
		width,
		1,
		centerText,
		textColor or { 1, 1, 1, 1 },
		lineHeight
	)
end

function render_primitives.load()
	tileSize = config.tileSize
end

return render_primitives
