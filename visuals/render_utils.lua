local config = require("config")
local tileSize
local render_utils = {}



--Review this function. Lighting should be way more dynamic
function render_utils:getAlpha(i, maxHeight, centerX, centerY, x, y, visible, base)
    local nudge = 0.1
    local heightFactor = (i) / maxHeight
    if not visible then
        return (math.max(0.1, (i - 0.7) / maxHeight) * base) + nudge
    else
        return (heightFactor * base) + nudge
    end
end


-- Returns the final color to be used based on visibility and exploration
function render_utils:getEffectiveColor(color, visible, explored)
    if visible then
        if color then
            return {
                (color[1] or 1),
                (color[2] or 1),
                (color[3] or 1),
                (color[4] or 1)
            }
        else
            return {1, 1, 1, 1}
        end
    elseif explored then
        return {0.961, 0.871, 0.702, .5} -- fog-of-war color
    end
    return nil
end

-- Takes a color and scales it by a set amount.
-- If no color is provided, defaults to white.
function render_utils:scaleColor(color, scale)
    if color then 
        return {
            (color[1] or 1) * scale,
            (color[2] or 1) * scale,
            (color[3] or 1) * scale,
            (color[4] or 1)
        }
    else
        return {1, 1, 1, 1}
    end
end


-- Converts XY map to XY screen coordinates based on camera center
function render_utils:getScreenCoords(x, y, centerX, centerY)
    local screenX = (x - centerX + love.graphics.getWidth() / tileSize / 2) * tileSize
    local screenY = (y - centerY + love.graphics.getHeight() / tileSize / 2) * tileSize
    return screenX, screenY
end


-- Gets distance between map positions and returns a normalized alpha value based on screen size
function render_utils:distanceBetween(x1, y1, x2, y2)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local tilesWide = screenWidth / tileSize
    local tilesHigh = screenHeight / tileSize

    local maxDist = math.sqrt((tilesWide / 2)^2 + (tilesHigh / 2)^2)
    local dist = math.sqrt((x1 - x2)^2 + (y1 - y2)^2)

    return math.min(math.max(1 - (dist / maxDist), 0.05), 1)
end



-- Gets a visual offset based on height and offset type
function render_utils:getOffset(i, offsetType, offset, x, y, centerX, centerY)
    if offsetType == 1 then
        local scale = 0.1
        return (i - 1) * offset * (x - centerX) * scale,
               (i - 1) * offset * (y - centerY) * scale
    elseif offsetType == 2 then
        return -(i - 1) * offset, -(i - 1) * offset
    end
    return 0, 0
end

-- Draws a filled rect (with optional outline) in screen coordinates
function render_utils:drawRect(xScreen, yScreen, width, height, color, outlineWidth, outlineColor, roundedAmount)
    local roundedAmountX = 0
    local roundedAmountY = 0

    if roundedAmount then
        roundedAmountX = width*roundedAmount
        roundedAmountY = height*roundedAmount
    end

    love.graphics.setColor(color)
    love.graphics.rectangle("fill", xScreen, yScreen, width, height, roundedAmountX, roundedAmountY)

    if outlineWidth and outlineColor then
        love.graphics.setLineWidth(outlineWidth)
        love.graphics.setColor(outlineColor)
        love.graphics.rectangle("line", xScreen, yScreen, width, height, roundedAmountX, roundedAmountY)
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draws a single character at screen coordinates, with optional color/alpha/outline
function render_utils:drawChar(xScreen, yScreen, text, color, alpha, outlineColor, centered, rotation, naturalRotation)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(text or "")
    local textHeight = font:getHeight(text)

    local dx, dy = 0, 0
    if centered then
        dx = (tileSize - textWidth) / 2
        dy = (tileSize - textHeight) / 2
    end

    -- Apply rotation if specified
    if rotation then
        rotation = math.rad(((rotation or 0) - (naturalRotation or 0)) % 360)

        -- Use love.graphics.newText to enable rotation
        local textObject = love.graphics.newText(font, text)

        love.graphics.push()
        love.graphics.translate(xScreen + dx + textWidth / 2, yScreen + dy + textHeight / 2)
        love.graphics.rotate(rotation)

        if outlineColor then
            love.graphics.setColor(outlineColor)
            love.graphics.draw(textObject, -textWidth / 2 + 1, -textHeight / 2 + 1)
        end

        local r, g, b, a = unpack(color or {1, 1, 1, 1})
        love.graphics.setColor(r, g, b, alpha or a)
        love.graphics.draw(textObject, -textWidth / 2, -textHeight / 2)

        love.graphics.pop()
    else
        if outlineColor then
            love.graphics.setColor(outlineColor)
            love.graphics.print(text, xScreen + dx + 1, yScreen + dy + 1)
        end

        local r, g, b, a = unpack(color or {1, 1, 1, 1})
        love.graphics.setColor(r, g, b, alpha or a)
        love.graphics.print(text, xScreen + dx, yScreen + dy)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draws a block of text line-by-line within a bounding box
function render_utils:drawTextBlock(texts, xScreen, yScreen, width, outline, centerText, color, lineHeight)

    lineHeight = lineHeight or tileSize
    if color then
        love.graphics.setColor(color)
    end

    for i, text in ipairs(texts) do
        local dx = outline * 2
        if centerText then
            dx = dx + ((width - font:getWidth(text)) / 2)
        end

        local drawX = xScreen + dx
        local drawY = yScreen + outline + ((i - 1) * lineHeight)

        love.graphics.print(text, drawX, drawY)
    end
end

-- Composite: draws a panel (box + text block inside)
function render_utils:drawPanel(xScreen, yScreen, width, height, fillColor, outlineColor, texts, centerText, textColor, lineHeight)
    self:drawRect(xScreen, yScreen, width, height, fillColor, 1, outlineColor)
    self:drawTextBlock(texts, xScreen, yScreen, width, 1, centerText, textColor or {1, 1, 1, 1}, lineHeight)
end

function render_utils:load()
    tileSize = config.tileSize

end


return render_utils
