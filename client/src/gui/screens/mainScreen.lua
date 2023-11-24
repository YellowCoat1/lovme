local mainScreen = Screen:extend()

local textBar = require 'gui.textBar'


function mainScreen:new()
    self:clearClickables()
    table.insert(self.textBoxes, textBar(0, 0, love.graphics.getWidth(), true, true))
end

function mainScreen:setDraw()

end

return mainScreen