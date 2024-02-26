local cardManager = {}

local connection = require 'connection'
local drawingHelper = require 'gui.drawingHelper'

-- contstants
local boxHeight = 80
local chatAddBoxHeight = 60

-- ordered chat list
-- 1st will be 1st displayed, and so on
cardManager.chatList = {}
-- cardManager.chatEnterCallback = function() end
-- testing code
do
    local chatList = cardManager.chatList
    
    local user = {}
    user.name = "bob"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "joe"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "george"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "harry"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "ce"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "ca"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "cg"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "aa"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "ab"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "bob"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "joe"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "george"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "harry"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "ce"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "ca"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "cg"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "aa"
    user.last = 10
    table.insert(chatList, user)
    local user = {}
    user.name = "ab"
    user.last = 10
    table.insert(chatList, user)
end

-- how much the card menu is scrolled up or down
cardManager.yOffset = 0
-- how much you're pushed back from moving off the ends too much
cardManager.endsVelocity  = 0
-- tracks accelerating speed when moving the cards up or down
cardManager.addedVelocity = 0

-- request contact list from server
connection.setContactListResponse(function(data)
    cardManager.chatList = data
end)

connection.request_contact_list()

function cardManager:draw()

    local bottomYOffset = -((#self.chatList-1) * boxHeight) 

    -- if scrolled above the top
    if self.yOffset > 2 then
        self.addedVelocity = 0
        -- slow it down
        self.yOffset = (self.yOffset-2) * 0.95
    -- if scrolled below the bottom
    elseif self.yOffset < -((#self.chatList-1) * boxHeight) then
        self.addedVelocity = 0
        local addOffset = (self.yOffset - bottomYOffset) * 0.95
        self.yOffset = bottomYOffset + addOffset
    end

    local velMax = 20
    local accelVal = 0.06 

    if love.keyboard.isDown("down") then
        self.yOffset = self.yOffset - 7 - self.addedVelocity
        if self.addedVelocity < velMax then
            self.addedVelocity = self.addedVelocity + accelVal
        end
    elseif love.keyboard.isDown("up") then
        self.yOffset = self.yOffset + 7 + self.addedVelocity
        if self.addedVelocity < velMax then
            self.addedVelocity = self.addedVelocity + accelVal
        end
    else 
        self.addedVelocity = 0
    end

    -- for every chat card
    for index, card in ipairs(self.chatList) do
        local cardY = (index-1)*boxHeight + self.yOffset + chatAddBoxHeight
        -- draw it if it's on screen
        if cardY > -boxHeight then  
            drawingHelper:square("color2", 0, cardY, love.graphics.getWidth(), boxHeight, "fill")
            drawingHelper:verticalLine("color3", cardY+boxHeight)
            drawingHelper:text(card.name, "color4", 15, 5 + cardY)
        end
    end
end

function cardManager:mouseClick(x, y)
    local startingIndex = math.abs((self.yOffset / boxHeight)) - 1
    startingIndex = math.floor(startingIndex)
    if startingIndex < 1 then startingIndex = 1 end 
    local indexEnd = math.floor(love.graphics.getHeight() / boxHeight) + 1
    
    for i=startingIndex, startingIndex + indexEnd do
        local cardY = (i-1)*boxHeight + self.yOffset + chatAddBoxHeight
        if y > cardY and y < cardY + boxHeight and i <= #self.chatList and y > chatAddBoxHeight then
            print(self.chatList[i].name)
            -- do stuff when a card is clicked
        end
    end

end

return cardManager