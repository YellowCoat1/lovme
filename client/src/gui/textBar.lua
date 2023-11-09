local textBar = Object:extend()
local clickable = require 'gui.clickable'

-- preset height for textbars
local HEIGHT = 50


function textBar:new(x, y, width)

    self.x = x
    self.y = y
    self.width = width
    self.active = false

    function self.clickedFunction()
        self.active = true
    end

    function self.notClickedFunction()
        self.active = false
    end

    self.clickable = clickable(x, y, width, HEIGHT, self.clickedFunction, self.notClickedFunction)
end

function textBar:mousePress(x,y)
    self.clickable:mousePress(x,y)
end

return textBar