local clickable = Object:extend()

function clickable:new(x,y,width,height,clickFunction, notClickedFunction)
    clickFunction = clickFunction or function() end
    notClickedFunction = notClickedFunction or function() end
    self.clickableX = x
    self.clickableY = y
    self.clickableWidth = width
    self.clickableHeight = height
    self.clickFunction = clickFunction
    self.notClickedFunction = notClickedFunction
end

local function pointWithinSquare(squareX, squareY, squareWidth, squareHeight, pointX, pointY)
    return pointX > squareX and pointX < squareX + squareWidth
    and pointY > squareY and pointY < squareY + squareHeight
end

function clickable:mousePress(clickX,clickY)
    if pointWithinSquare(self.clickableX, self.clickableY, self.clickableWidth, self.clickableHeight, clickX, clickY) then
        self.clickFunction()    
    else
        self.notClickedFunction()
    end
end

return clickable