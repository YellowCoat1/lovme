--template screen
Screen = Object:extend()

function Screen:new()
    self.textBoxes = {}
    self.clickables = {} 
end

function Screen:clearClickables()
    self.textBoxes = {}
    self.clickables = {}
end

function Screen:mouseClickSettable(x,y) end

function Screen:mouseClick(x, y)
    self:mouseClickSettable(x,y)
    for _,textBoxClickable in pairs(self.textBoxes) do
        textBoxClickable:mousePress(x, y)
    end
    for _,singleClickable in pairs(self.clickables) do
        singleClickable:mousePress(x, y)
    end
end
-- keyPressSettable

function Screen:keyPressSettable(key) end

function Screen:keyPressed(key)
    self:keyPressSettable(key)
    for _,v in pairs(self.textBoxes) do
        v:keypress(key)
    end
end


function Screen:start()

end

function Screen:draw()
    self:setDraw()
    for _,v in ipairs(self.textBoxes) do
        v:draw()
    end
end

function Screen:setDraw()

end