local chatsScreen = Screen:extend()

local cached = require 'cached'
local textBar = require 'gui.textBar'
local clickable = require 'gui.clickable'

local drawingHelper = require 'gui.drawingHelper'
local cardManager = require 'gui.cardManager'

local connection = require 'connection'

local chatAddBoxHeight = 60
local chatAddTextOffset = (chatAddBoxHeight-Font:getHeight("|"))/4
local getTime = love.timer.getTime

function chatsScreen:new()
    self:clearClickables()

    local chatAddTextBox = textBar(10, chatAddTextOffset, love.graphics.getWidth(), false, true, true)
    chatAddTextBox:setText("test")
    chatAddTextBox:setLimit(16)
    table.insert(self.textBoxes, chatAddTextBox)

    local plusSignClickable = clickable(love.graphics.getWidth()-Font:getWidth("+")-15,0,100,chatAddBoxHeight,function() 
        self:chatAdd()
    end)
    table.insert(self.clickables, plusSignClickable)


    self.confirmTitleTimer = getTime()
    self.confirmTitle = "eeee"

    local confirmTitleTimer = getTime()
    local confirmTitle = self.confirmTitle


    connection.setContactAddResponse(function(data) 
        local message = data.message
        confirmTitle = message
        confirmTitleTimer = getTime() + 1.5
    end)
end

function chatsScreen:chatAdd()
    local chatAddTextBox = self.textBoxes[1]
    local chatAddText = chatAddTextBox.text
    connection.contactAdd(chatAddText)
    self.confirmTitle = chatAddText
    chatAddTextBox:setText("")
end

function chatsScreen:mouseClickSettable(x, y)
    cardManager:mouseClick(x, y)
end

function chatsScreen:setDraw()
    
    -- draw chat cards
    cardManager:draw()

    -- draw top chat add bar
    drawingHelper:square("color2", 0, 0, love.graphics.getWidth(), chatAddBoxHeight, "fill")
    drawingHelper:verticalLine("color3", chatAddBoxHeight)
    local plusSignScale = 1.3
    drawingHelper:text("+", "color4", love.graphics.getWidth()-Font:getWidth("+")-15, 0, plusSignScale)

    if self.confirmTitleTimer > getTime() then
        drawingHelper:text(self.confirmTitle, "color4", 10, chatAddTextOffset + Font:getHeight("|") - 5, 0.5)
    end
end

function chatsScreen:keyPressSettable(key)
    if key == "return" then 
        self:chatAdd()
    end
end

return chatsScreen