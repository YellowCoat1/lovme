local login = {}

local drawingHelper = require 'gui.drawingHelper'
local connection = require 'connection'

local textBar = require 'gui.textBar'
local textBoxes = {}

local responseTimer = love.timer.getTime()
local responseText = ""
local responseText2 = ""

local usernameTextbar = textBar(0, 135, love.graphics.getWidth(), false, true, true, "color1")
usernameTextbar:setText("(user)")
usernameTextbar:setLimit(16)
table.insert(textBoxes, usernameTextbar)

local passwordTextbar = textBar(0, 225, love.graphics.getWidth(), false, false, true, "color1")
passwordTextbar:setText("(pass)")
passwordTextbar:setLimit(16)
table.insert(textBoxes, passwordTextbar)

function login:draw()
    local screenWidth = love.graphics.getWidth()
    local fontHeight = Font:getHeight("|")

    drawingHelper:square("color2", 0, 0, love.graphics.getWidth(), 70)
    drawingHelper:text("ASDASDASD", "color4", 0, 0, 2)

    drawingHelper:square("color2", 0, 135, love.graphics.getWidth(), Font:getHeight("|"))
    drawingHelper:text("Username:", "color3", 0, 100)

    drawingHelper:square("color2", 0, 225, love.graphics.getWidth(), Font:getHeight("|"))
    drawingHelper:text("Password:", "color3", 0, 190)

    if responseTimer > love.timer.getTime() then
        love.graphics.print(responseText, 0, 300)
        love.graphics.print(responseText2, 0, 300 + Font:getHeight("|"))
    end

    for _,textBox in ipairs(textBoxes) do
        textBox:draw()
    end
end

function login:loginAttempt()
    local connectionReqStatus = connection:login(username, password)

    -- temp autologin
    connection:forceLogin()
    return
    
    if not connectionReqStatus then
        responseTimer = love.timer.getTime() + 2
        responseText = "server error :P"
        responseText2 = "(are you connected?)"
    end
end

function login.keypressed(key)
    local username =  usernameTextbar.text
    local password = passwordTextbar.text
    if key == "return" and username ~= "" and password ~= "" then
        login:loginAttempt()
    end
    for _,textBox in ipairs(textBoxes) do
        textBox:keypress(key)
    end
end

function login:mousepressed(x, y)
    for _,textBox in pairs(textBoxes) do
        textBox:mousePress(x, y)
    end
end


return login