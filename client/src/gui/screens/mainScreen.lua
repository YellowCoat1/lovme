local mainScreen = Screen:extend()

local textBar = require 'gui.textBar'

function mainScreen:new()
    self:clearClickables()
    table.insert(self.textBoxes, textBar(0,0,love.graphics.getWidth(), true, "TEST", true, nil, true))
end

return mainScreen