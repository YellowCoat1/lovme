local login = {}

local drawingHelper = require 'gui.drawingHelper'
local connection = require 'connection'

local textBar = require 'gui.textBar'
local textBoxes = {}

local loginResponseTimer = love.timer.getTime()
local registerResponseTimer = love.timer.getTime()

-- stores the status text shown for login/register
local loginResponseText = {"lorum ipsum", "lorum ipsum"}
local registerResponseText = {"lorum ipsum", "lorum ipsum"}

local loginY = 65
local registerY = 350

-- login textbars
local usernameTextbar = textBar(0, loginY+70, love.graphics.getWidth(), false, true, true, "color1")
usernameTextbar:setText("(user)")
usernameTextbar:setLimit(16)
table.insert(textBoxes, usernameTextbar)

local passwordTextbar = textBar(0, loginY+160, love.graphics.getWidth(), false, false, true, "color1")
passwordTextbar:setText("(pass)")
passwordTextbar:setLimit(16)
table.insert(textBoxes, passwordTextbar)

-- register textbars
local usernameRegTextbar = textBar(0, registerY+70, love.graphics.getWidth(), false, false, true, "color1")
usernameTextbar:setText("(user)")
usernameTextbar:setLimit(16)
table.insert(textBoxes, usernameRegTextbar)

local passwordRegTextbar = textBar(0, registerY+160, love.graphics.getWidth(), false, false, true, "color1")
passwordTextbar:setText("(pass)")
passwordTextbar:setLimit(16)
table.insert(textBoxes, passwordRegTextbar)

-- on login fail
connection:setLoginFailResponse(function()
    -- displays login fail text 
    login.loginFail()
end)

connection:setRegisterResponse(function(username)
    login:registerSuccess(username)
end)
connection:setRegisterFailResponse(function(errorCode)
    login:registerFail(errorCode)
end)

local function drawLogin()
    drawingHelper:text("Login", "color2", 0, loginY)

    drawingHelper:square("color2", 0, loginY+70, love.graphics.getWidth(), Font:getHeight("|"))
    drawingHelper:text("Username:", "color3", 0, loginY + 35)
    
    drawingHelper:square("color2", 0, loginY+160, love.graphics.getWidth(), Font:getHeight("|"))
    drawingHelper:text("Password:", "color3", 0, loginY + 125)

    if loginResponseTimer > love.timer.getTime() then
        love.graphics.print(loginResponseText[1], 200, loginY)
        love.graphics.print(loginResponseText[2], 200, loginY + Font:getHeight("|") - 5)
    end
end

local function drawRegister()
    drawingHelper:text("Register", "color2", 0, registerY)

    drawingHelper:square("color2", 0, registerY+70, love.graphics.getWidth(), Font:getHeight("|"))
    drawingHelper:text("Username:", "color3", 0, registerY + 35)
    
    drawingHelper:square("color2", 0, registerY+160, love.graphics.getWidth(), Font:getHeight("|"))
    drawingHelper:text("Password:", "color3", 0, registerY + 125)

    if registerResponseTimer > love.timer.getTime() then
        love.graphics.print(registerResponseText[1], 200, registerY)
        love.graphics.print(registerResponseText[2], 200, registerY + Font:getHeight("|") - 5)
    end
end

function login:draw()
    local screenWidth = love.graphics.getWidth()
    local fontHeight = Font:getHeight("|")

    -- drawingHelper:square("color2", 0, 0, love.graphics.getWidth(), 70)
    drawingHelper:text("FUNKY APP", "color2", 0, 0, 2)

    drawLogin()
    drawRegister()

    for _,textBox in ipairs(textBoxes) do
        textBox:draw()
    end
end

local function arrowKeyPressed(key)
    -- gets the currently selected textbox
    local selectedTextbox 
    for index,textBox in ipairs(textBoxes) do
        if textBox.active then 
            selectedTextbox = index
            break
        end
    end

    -- if none are selected
    if selectedTextbox == nil then
        return
    end

    local moveUp = key == "up" and selectedTextbox ~= 1 
    local moveDown = key == "down" and selectedTextbox ~= 4
    
    if moveUp then
        textBoxes[selectedTextbox-1].active = true
    elseif moveDown then
        textBoxes[selectedTextbox+1].active = true
    end

    if moveUp or moveDown then
        textBoxes[selectedTextbox].active = false
    end
end

local function enterKeyPressed()
    if usernameTextbar.active or passwordTextbar.active then
        login:loginAttempt()
    elseif usernameRegTextbar.active or passwordRegTextbar.active then
        login:registerAttempt()
    end
end

function login:registerAttempt()
    local username = usernameRegTextbar.text
    local password = passwordRegTextbar.text
    if username == "" or password == "" then return end

    local registerResult, reason = connection.registerUser(username, password)
    
    if not registerResult then
        registerResponseTimer = love.timer.getTime() + 2
        registerResponseText[1] = "connection error :P"
        registerResponseText[2] = "(are you connected?)"
    else
        usernameRegTextbar.text = ""
        passwordRegTextbar.text = ""
    end
end

function login:registerSuccess(username)
    registerResponseTimer = love.timer.getTime() + 2
    registerResponseText[1] = "register success!"
    registerResponseText[2] = "user " .. username .. " registered!" 
end

function login:registerFail(errorCode)
    registerResponseTimer = love.timer.getTime() + 2
    registerResponseText[1] = "register fail!"

    if not errorCode then
        registerResponseText[2] = "unknown error!"
    elseif errorCode == "usrExist" then
        registerResponseText[2] = "user already exists!"
    elseif errorCode == "serverErr" then
        registerResponseText[2] = "server error :("
    end
end


function login:loginAttempt()
    if usernameTextbar.text == "" or passwordTextbar.text == "" then return end
    local username = usernameTextbar.text
    local password = passwordTextbar.text
    local connectionReqStatus = connection:login(username, password)
    
    -- temp autologin
    -- connection:forceLogin()
    -- do return end
    
    if connectionReqStatus then
        passwordTextbar:setText("")
        usernameTextbar:setText("")        
    else
        loginResponseTimer = love.timer.getTime() + 2
        loginResponseText[1] = "connection error :P"
        loginResponseText[2] = "(are you connected?)"
    end
end

function login.loginFail()
    loginResponseTimer = love.timer.getTime() + 2
    loginResponseText[1] = "login fail :("
    loginResponseText[2] = "(is your pass correct?)"
end

function login.keypressed(key)
    local username =  usernameTextbar.text
    local password = passwordTextbar.text

    if key == "return" then
        enterKeyPressed()
    elseif key == "up" or key == "down" then
        arrowKeyPressed(key)
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