local gui = {}

local color1 = {27,45,72}
local color2 = {44,69,107}
local color3 = {60,100,169}
local color4 = {71,121,196}

local font = love.graphics.newFont("Roboto-Regular.ttf")
local getTime = love.timer.getTime
local time = getTime()

local abs = math.abs


-- colors here are a table of values from 0 to 255
-- love2d uses multiple variables from 0 to 1
-- this converts between them
local function unpackColor(color)
    return love.math.colorFromBytes(color[1], color[2], color[3])
end

local function lerp(start, stop, input)
    return (start + (stop - start) * input);
end

local function notifStart(message)
    guiState.notif.on = true
    guiState.notif.t = 5
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


function gui.draw()
    love.graphics.setBackgroundColor(unpackColor(color1))
    coloredSquare(color1, 10, 10, 50, 50)
    coloredSquare(color2, 10, 70, 50, 50)
    coloredSquare(color3, 10, 130, 50, 50)
    coloredSquare(color4, 10, 190, 50, 50)
end




return gui