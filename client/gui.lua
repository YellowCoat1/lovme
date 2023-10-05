local gui = {}

local color1 = {27,45,72}
local color2 = {44,69,107}
local color3 = {60,100,169}
local color4 = {71,121,196}

local fb = love.math.colorFromBytes
local font = love.graphics.newFont("Roboto-Regular.ttf")

local guiState = {}

local function coloredSquare(color, x, y, w, h, rtype)
    rtype = rtype or "fill"
    local pr,pg,pb,pa = love.graphics.getColor()
    love.graphics.setColor(fb(color[1], color[2], color[3]))
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(pr,pg,pb,pa)
end

function gui.draw()
    local bgColor = color1
    love.graphics.setBackgroundColor(fb(bgColor[1], bgColor[2], bgColor[3]))
    coloredSquare(color1, 10, 10, 50, 50)
    coloredSquare(color2, 10, 70, 50, 50)
    coloredSquare(color3, 10, 130, 50, 50)
    coloredSquare(color4, 10, 190, 50, 50)
end




return gui