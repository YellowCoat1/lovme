local drawingHelper = {}

drawingHelper.color1 = {27,45,72}
drawingHelper.color2 = {44,69,107}
drawingHelper.color3 = {60,100,169}
drawingHelper.color4 = {71,121,196}


-- colors here are a table of values from 0 to 255
-- love2d uses multiple variables from 0 to 1
-- this converts between them
local function unpackColor(color)
    return love.math.colorFromBytes(color[1], color[2], color[3])
end

local width = love.graphics.getWidth()

function drawingHelper:getColor(colorName)
    return unpackColor(self[colorName])
end

function drawingHelper:square(color, x, y, w, h, rtype)
    rtype = rtype or "fill"
    local pr,pg,pb,pa = love.graphics.getColor()
    love.graphics.setColor(self:getColor(color))
    love.graphics.rectangle(rtype, x, y, w, h)
    love.graphics.setColor(pr,pg,pb,pa)
end

function drawingHelper:line(color, x1, y1, x2, y2)
    local pr,pg,pb,pa = love.graphics.getColor()
    love.graphics.setColor(self:getColor(color))
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.setColor(pr,pg,pb,pa)
end

function drawingHelper:verticalLine(color, y)
    local pr,pg,pb,pa = love.graphics.getColor()
    love.graphics.setColor(self:getColor(color))
    love.graphics.line(0, y, width, y)
    love.graphics.setColor(pr,pg,pb,pa)
end

function drawingHelper:text(text, color, x, y, textScale)
    local pr,pg,pb,pa = love.graphics.getColor()
    love.graphics.setColor(self:getColor(color))
    love.graphics.print(text, x, y, 0, textScale)
    love.graphics.setColor(pr,pg,pb,pa)
end

return drawingHelper