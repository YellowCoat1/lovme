local gui = {}

local color1 = {27,45,72}
local color2 = {44,69,107}
local color3 = {60,100,169}
local color4 = {71,121,196}

-- font is global
love.keyboard.setKeyRepeat(true)
Font = love.graphics.newFont("assets/Roboto-Regular.ttf", 64)
love.graphics.setFont(Font)
local bubble = love.graphics.newImage("assets/bubble.png")
local gear = love.graphics.newImage("assets/gear.png")


local clickable = require 'gui.clickable'
local textBar = require 'gui.textBar'
local tab = require 'gui.tab'


local getTime = love.timer.getTime
local time
local abs = math.abs

-- storing window width and height
local width = love.graphics.getWidth()
local height = love.graphics.getHeight()

-- loading | main | chat | settings
local guiState = "main"

-- colors here are a table of values from 0 to 255
-- love2d uses multiple variables from 0 to 1
-- this converts between them
local function unpackColor(color)
    return love.math.colorFromBytes(color[1], color[2], color[3])
end


-- contact list
local contactList = {} --cashed.getContactList()

local mainClickables = {}

-- linear interpolation
local function lerp(start, stop, input)
    return (start + (stop - start) * input);
end

-- start a notification
local function notifStart(message)
    guiState.notif.on = true
    guiState.notif.t = 5
end

local function coloredVerticalLine(color, y)
    local pr,pg,pb,pa = love.graphics.getColor()
    love.graphics.setColor(unpackColor(color))
    love.graphics.line(0, y, width, y)
    love.graphics.setColor(pr,pg,pb,pa)
end

local function coloredLine(color, x1, y1, x2, y2)
    local pr,pg,pb,pa = love.graphics.getColor()
    love.graphics.setColor(unpackColor(color))
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.setColor(pr,pg,pb,pa)
end

-- draws a square. that is colored.
local function coloredSquare(color, x, y, w, h, rtype)
    rtype = rtype or "fill"
    local pr,pg,pb,pa = love.graphics.getColor()
    love.graphics.setColor(unpackColor(color))
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(pr,pg,pb,pa)
end

-- draw a notification, if there was one
local function drawNotif()
    local notif = guiState.notif
    -- timer relative to the start of the notif
    local relativeTimer = time - notif.t
    -- if the notif is not on
    if not notif.on or notif.t <= time then return end
    if notif.t + 3 > relativeTimer then notif.on = false end
end


local function drawBottomBar()
    coloredSquare(color2, 0, 600, width, 100)
    coloredVerticalLine(color3, 600)
    coloredLine(color3, width/2, 600, width/2, height)
    love.graphics.draw(bubble, width/6.5, 610, 0, 0.5, 0.5, 32, 64)
    love.graphics.draw(gear, width/1.45, 627, 0, 0.25, 0.25, 32, 64)
end

table.insert(mainClickables, clickable(0, 600, width/2, 700-600, function() 
    tab.setScreen("main") 
end))
table.insert(mainClickables, clickable(width/2, 600, width/2, 700-600, function() 
    tab.setScreen("settings") 
end))


function gui.draw()
    love.graphics.setBackgroundColor(unpackColor(color1))
    drawBottomBar()

    tab.draw()
    
    -- coloredSquare(color1, 10, 10, 50, 50)
    -- coloredSquare(color2, 10, 70, 50, 50)
    -- coloredSquare(color3, 10, 130, 50, 50)
    -- coloredSquare(color4, 10, 190, 50, 50)
end

function gui.keypressed(key)
    tab.keypressed(key)
end

function gui.mousePressed(x, y, button)
    if button ~= 1 then return end
    for i,workingClickable in ipairs(mainClickables) do 
        workingClickable:mousePress(x,y)
    end
    tab.mouseClick(x, y)
end


return gui