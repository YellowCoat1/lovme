local gui = {}

-- font is global
love.keyboard.setKeyRepeat(true)
Font = love.graphics.newFont("assets/Roboto-Regular.ttf", 32)
love.graphics.setFont(Font)
local bubble = love.graphics.newImage("assets/bubble.png")
local gear = love.graphics.newImage("assets/gear.png")

local cached = require 'cached'
local connection = require 'connection'
local drawingHelper = require 'gui.drawingHelper'

local clickable = require 'gui.clickable'
-- local textBar = require 'gui.textBar'
local tab = require 'gui.tab'


local getTime = love.timer.getTime
local time
local abs = math.abs

-- storing window width and height
local width = love.graphics.getWidth()
local height = love.graphics.getHeight()

local loginUp = true
local login = require 'gui.login'

-- contact list
local contactList = cached.getValue("contactList")
-- if it fails use an empty table
if not contactList then
    contactList = {}
    connection.request_contact_list(contactList)
    connection.setContactListResponse(function(data) 
        contactList = data
    end)
end

local mainClickables = {}

-- linear interpolation
local function lerp(start, stop, input)
    return (start + (stop - start) * input);
end

local function drawBottomBar()
    drawingHelper:square("color2", 0, 600, width, 100)
    drawingHelper:verticalLine("color3", 600)
    drawingHelper:line("color3", width/2, 600, width/2, height)
    love.graphics.draw(bubble, width/6.5, 610, 0, 0.5, 0.5, 32, 64)
    love.graphics.draw(gear, width/1.45, 627, 0, 0.25, 0.25, 32, 64)
end


local loginCreds = cached.getValue("loginCreds")
if loginCreds then
    connection:login(loginCreds.user, loginCreds.pass)
end

connection.setLoginResponse(function() 
    currentTab = "main"
end)

table.insert(mainClickables, clickable(0, 600, width/2, 700-600, function() 
    tab.setScreen("main") 
end))
table.insert(mainClickables, clickable(width/2, 600, width/2, 700-600, function() 
    tab.setScreen("settings") 
end))


function gui.draw()
    love.graphics.setBackgroundColor(drawingHelper:getColor("color1"))
    
    
    if loginUp then
        login.draw()
    else
        tab.draw()
        drawBottomBar()
    end
    -- drawingHelper:square("color2", 10, 70, 50, 50)
    -- drawingHelper:square("color1", 10, 10, 50, 50)
    -- drawingHelper:square("color3", 10, 130, 50, 50)
    -- drawingHelper:square("color4", 10, 190, 50, 50)
end

function gui.keypressed(key)
    if loginUp then
        login.keypressed(key)
    else
        tab.keypressed(key)
    end
end

function gui.mousePressed(x, y, button)
    if button ~= 1 then return end

    if loginUp then
        login:mousepressed(x,y)
        return
    end

    for i,workingClickable in ipairs(mainClickables) do 
        workingClickable:mousePress(x,y)
    end
    
    -- if it's within the tab's domain, register a mouse click
    if y < 600 then
        tab.mouseClick(x, y)
    end
end


return gui