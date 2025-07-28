local renderer = {}

local radial = 1;
local maxHeight = 5;

function renderer:switchRadial()
    radial = (radial % 3) + 1
end


function renderer:drawEntity(char, tileSize, x, y) -- TODO only draw if visible
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(char)
    local textHeight = font:getHeight()
    local xx = x * tileSize + (tileSize - textWidth) / 2
    local yy = y * tileSize + (tileSize - textHeight) / 2
    love.graphics.print(char, xx, yy)
end

function renderer:draw(chars, tileSize, x, y, visible)
    local font = love.graphics.getFont()
    local offset = 0.2*tileSize
    for i, char in ipairs(chars) do
        char=char.char  
        
        local textWidth = font:getWidth(char)
        local textHeight = font:getHeight()
        local xx = x * tileSize + (tileSize - textWidth) / 2
        local yy = y * tileSize + (tileSize - textHeight) / 2
        if not visible then
            love.graphics.setColor(0.961, 0.871, 0.702, (i+0.5)/maxHeight)
        else
            love.graphics.setColor(1, 1, 1, (i+0.5)/maxHeight)
        end

        if radial == 1 then  -- TODO: need a lot of touchups

            local camX = love.graphics.getWidth() / tileSize / 2
            local camY = love.graphics.getHeight() / tileSize / 2
            local dx = x - camX
            local dy = y - camY

            local scale = 0.2

            local drawX = xx + (i - 1) * offset * dx * scale
            local drawY = yy + (i - 1) * offset * dy * scale

            love.graphics.print(char, drawX, drawY)

        elseif radial == 2 then
            love.graphics.print(char, xx - (i - 1) * offset, yy - (i - 1) * offset)
         
        elseif radial == 3 and i == 1 then
            love.graphics.print(char, xx, yy)
        end
        love.graphics.setColor(1, 1, 1, 1) 
    end
end



return renderer