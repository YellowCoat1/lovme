local settings = Screen:extend()

local textBar = require 'gui.textBar'

function settings:new()
    self:clearClickables()
end

return settings