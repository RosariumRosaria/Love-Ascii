local renderer = {}
local radial = 1;
local maxHeight = 5;
local visuals = require("visuals.visuals")

function renderer:switchRadial()
    radial = (radial % 3) + 1
end


function renderer:drawEntity(char, tileSize, x, y) 
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(char)
    local textHeight = font:getHeight()
    local xx = x * tileSize + (tileSize - textWidth)
    local yy = y * tileSize + (tileSize - textHeight)
    love.graphics.print(char, xx, yy)
end

function renderer:draw(chars, tileSize, x, y, centerX, centerY, visible)
    --TODO: Why is this here? probably be moved to renderer?
    local drawX = x - centerX + love.graphics.getWidth() / tileSize / 2
    local drawY = y - centerY + love.graphics.getHeight() / tileSize / 2
    local font = love.graphics.getFont()
    local offset = 0.2*tileSize
    for i, char in ipairs(chars) do
        char=char.char  
        
        local textWidth = font:getWidth(char)
        local textHeight = font:getHeight()
        local xx = drawX * tileSize + (tileSize - textWidth)/2
        local yy = drawY * tileSize + (tileSize - textHeight)/2
        if not visible then
            love.graphics.setColor(0.961, 0.871, 0.702, ((i-0.75)/maxHeight))
        else
            love.graphics.setColor(1, 1, 1, (i+0.5)/maxHeight)
        end

        if radial == 1 then  -- TODO: need a lot of touchups

            local camX = love.graphics.getWidth() / tileSize / 2
            local camY = love.graphics.getHeight() / tileSize / 2
            local dx = drawX - camX
            local dy = drawY - camY

            local scale = 0.2

            local drawX = xx + (i - 1) * offset * dx * scale
            local drawY = yy + (i - 1) * offset * dy * scale

            love.graphics.print(char, drawX, drawY)

        elseif radial == 2 then
            love.graphics.print(char, xx - (i - 1) * offset, yy - (i - 1) * offset)
         
        elseif radial == 3 and i == 1 then
            love.graphics.print(char, xx, yy)
        end

        local visual = visuals:getVisual(x, y, z)
        if visual then
            love.graphics.setColor(visual.colors[1]) 
            love.graphics.rectangle("fill", xx, yy, tileSize, tileSize) --TODO, maybe some way to make what type of effect dynamic
        end

        love.graphics.setColor(1, 1, 1, 1) 
    end
end



return renderer