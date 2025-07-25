local render = {}

local radial = true;
local maxHeight = 5;
local function coverUp(x, y, tileSize)

    love.graphics.setColor(0, 0, 0, 1)

    love.graphics.rectangle("fill", x * tileSize, y * tileSize, tileSize, tileSize)

    love.graphics.setColor(1, 1, 1, 1)
end

function render:switchRadial()
    radial = not radial
end

function render:drawEntity(char, tileSize, x, y)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(char)
        local textHeight = font:getHeight()
        local xx = x * tileSize + (tileSize - textWidth) / 2
        local yy = y * tileSize + (tileSize - textHeight) / 2
        coverUp(x, y, tileSize)
        love.graphics.print(char, xx, yy)
end

function render:draw(chars, tileSize, x, y, isEntity)
    local font = love.graphics.getFont()

    local offset = 0.2*tileSize
    print(chars[1].char)
    for i, char in ipairs(chars) do
        char=char.char or char
        local textWidth = font:getWidth(char)
        local textHeight = font:getHeight()
        local xx = x * tileSize + (tileSize - textWidth) / 2
        local yy = y * tileSize + (tileSize - textHeight) / 2
        if isEntity then

        else
            love.graphics.setColor(1, 1, 1, i/maxHeight)
            if radial then
                -- camera center in tile units
                local camX = love.graphics.getWidth() / tileSize / 2
                local camY = love.graphics.getHeight() / tileSize / 2

                local dx = x - camX
                local dy = y - camY

                local scale = 0.1 -- tweak this for more/less lean

                local drawX = xx + (i - 1) * offset * dx * scale
                local drawY = yy + (i - 1) * offset * dy * scale

            love.graphics.print(char, drawX, drawY)

            else
                love.graphics.print(char, xx-((i-1)*offset), yy-((i-1)*offset))
            end
        end 
        love.graphics.setColor(1, 1, 1, 1) 
    end
end



return render