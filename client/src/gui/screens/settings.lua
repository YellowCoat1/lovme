local settings = Screen:extend()

local textBar = require 'gui.textBar'

function settings:new()
    self:clearClickables()
    table.insert(self.textBoxes, textBar(0, 0, love.graphics.getWidth(), true, true))
end

return settings