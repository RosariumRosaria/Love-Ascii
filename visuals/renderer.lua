
local renderer = {}
local radial = 1;
local maxHeight = 5;
local visuals = require("visuals.visuals")

function renderer:distanceBetween(x, y, xx, yy, tileSize)

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local centerX = screenWidth / (tileSize * 2)
    local centerY = screenHeight / (tileSize * 2)

    local maxDist = math.sqrt(centerX^2 + centerY^2)
    local dist = math.sqrt((x - xx)^2 + (y - yy)^2)
    local ret = 1.1 - (dist / maxDist)

    return math.min(math.max(ret, 0), 1)  
end

function renderer:getScreenCoords(x, y, centerX, centerY, tileSize)
    local screenX = (x - centerX + love.graphics.getWidth() / tileSize / 2) * tileSize
    local screenY = (y - centerY + love.graphics.getHeight() / tileSize / 2) * tileSize

    return screenX, screenY
end

function renderer:getAlpha(i, maxHeight, centerX, centerY, x, y, tileSize, visible)
    local base = renderer:distanceBetween(centerX, centerY, x, y, tileSize)
    local heightFactor = (i + 1) / maxHeight
    if not visible then
        return math.max(0.1, (i - 0.8) / maxHeight) * base * base
    else
        return heightFactor * base
    end
end

function renderer:getRadialOffset(i, offset, x, y, centerX, centerY)
    if radial == 1 then
        local scale = 0.2
        return (i - 1) * offset * (x - centerX) * scale,
               (i - 1) * offset * (y - centerY) * scale
    elseif radial == 2 then
        return -(i - 1) * offset, -(i - 1) * offset
    end

    return 0, 0
end


function renderer:switchRadial()
    radial = (radial % 3) + 1
end

function renderer:scaleColor(color, scale, alpha)
    love.graphics.setColor(
        color[1] * scale,
        color[2] * scale,
        color[3] * scale,
        color[4])
end

function renderer:drawVisual(visual, tileSize, x, y)
        if visual then 
            local visualSize = visual.sizes[visual.i]*tileSize
            if visual.decay then 
                renderer:scaleColor(visual.colors[1], visual.lifespan/visual.initialSpan)
            else
                love.graphics.setColor(visual.colors[visual.i]) 
            end
             
            love.graphics.rectangle("fill", x+((tileSize-visualSize)/2), y+((tileSize-visualSize)/2), visualSize, visualSize,visualSize/4, visualSize/4) --TODO, maybe some way to make what type of effect dynamic, also consider cases where parts aren't defined 
        end
end

function renderer:drawEntity(char, tileSize, x, y, centerX, centerY)
    local screenX, screenY = self:getScreenCoords(x, y, centerX, centerY, tileSize)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(char)
    local textHeight = font:getHeight()
    local xx = screenX + (tileSize - textWidth) / 2
    local yy = screenY + (tileSize - textHeight) / 2
    local alpha = renderer:distanceBetween(centerX, centerY, x, y, tileSize)

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(char, xx, yy)
    love.graphics.setColor(1, 1, 1, 1)  
end

function renderer:draw(chars, tileSize, x, y, centerX, centerY, visible)
    local font = love.graphics.getFont()
    local textHeight = font:getHeight()
    local offset = 0.25*tileSize
    local screenX, screenY = self:getScreenCoords(x, y, centerX, centerY, tileSize)

    if radial == 3 then    
        love.graphics.setColor(0.5, 0.5, 0.5, 0.1)
        love.graphics.rectangle("line", screenX, screenY, tileSize, tileSize)
        love.graphics.setColor(1, 1, 1, 1)
    end

    for i, tile in ipairs(chars) do

        local char=tile.char  
        local textWidth = font:getWidth(char)
        local xx = screenX + (tileSize - textWidth)/2
        local yy = screenY + (tileSize - textHeight)/2
        local alpha = self:getAlpha(i, maxHeight, centerX, centerY, x, y, tileSize, visible)

        if not visible then
            love.graphics.setColor(0.961, 0.871, 0.702, alpha/2)
        else
            if tile.color then
                renderer:scaleColor(tile.color, alpha)
            else
                love.graphics.setColor(1, 1, 1, alpha)
            end
        end

        local dx, dy = self:getRadialOffset(i, offset, x, y, centerX, centerY)
        love.graphics.print(char, xx + dx, yy + dy)
        renderer:drawVisual(visuals:getVisual(x, y, i), tileSize, screenX, screenY)
        love.graphics.setColor(1, 1, 1, 1) 
    end
end



return renderer