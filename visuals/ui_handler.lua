local ui_handler = {
    uiList = {}
}

function ui_handler:addUI(x,y,width,height,name,color,outline,outlinecolor,centerText)
    table.insert(ui_handler.uiList, {x=x,y=y,height=height,width=width,name=name,color=color,outline=outline,outlinecolor=outlinecolor,texts={},centerText=centerText})
end

function ui_handler:getUI(name)
    for _, ui in ipairs(ui_handler.uiList) do
        if ui.name == name then
            return ui
        end
    end
end

function ui_handler:addTextToUI(ui, text)
    if not ui then
        return false
    end
    table.insert(ui.texts, text)
    
    local font = love.graphics.getFont()
    local textHeight = font:getHeight()
    if (#ui.texts*textHeight > ui.height) then 
        table.remove(ui.texts, 1)
    end

end

function ui_handler:drawUI(ui)
    love.graphics.setColor(ui.color)
    love.graphics.rectangle("fill", ui.x, ui.y, ui.width, ui.height)

    love.graphics.setLineWidth(ui.outline or 1)
    love.graphics.setColor(ui.outlinecolor)
    love.graphics.rectangle("line", ui.x, ui.y, ui.width, ui.height)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1, 1)
end


function ui_handler:addTextToUIByName(name, text)
    ui_handler:addTextToUI(ui_handler:getUI(name), text)
end

function ui_handler:printUI(ui)
    local scale = 1
    local font = love.graphics.newFont(16*scale)
    local textHeight = font:getHeight()

    love.graphics.setFont(font) 
    for i, text in ipairs(ui.texts) do
        local dx = ui.outline * 2
        if (ui.centerText) then
            dx =  dx + ((ui.width-font:getWidth(text))/2)
        end
        love.graphics.print(text, ui.x + dx, ui.y + ui.outline + ((i-1)*textHeight))

    end
end

function ui_handler:load()
    local screenHeight = love.graphics.getHeight() 
    local screenWidth = love.graphics.getWidth() 
    local outline = screenWidth/400
    local buffer = 4*outline
    local width  = screenWidth / 6
    local startX = screenWidth - width - buffer
    local height = (screenHeight * 4 / 6) - buffer
    local startY = height + (2*buffer)
    local black =  {0, 0, 0, 0.5}
    local white =  {1, 1, 1, 0.5}


    ui_handler:addUI(startX,buffer,width,height,"terminal",black,outline,white)
    ui_handler:addUI(startX,startY,width, screenHeight - height - (4*buffer),"status",black,outline,white)
end

function ui_handler:draw(player)
    local status = ui_handler:getUI("status")
    status.texts = {}

    for statName, stat in pairs(player.stats) do
        local current = stat[statName]
        local max = stat["max" .. statName:gsub("^%l", string.upper)]
        ui_handler:addTextToUIByName("status", statName .. ": " .. current .. " / " .. max)
    end


    for _, ui in ipairs(self.uiList) do
        ui_handler:drawUI(ui)
        ui_handler:printUI(ui)
    end
end

return ui_handler