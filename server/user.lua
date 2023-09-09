-- user object file
local user = Object:extend()

function user:new(sessionID, sharedKey)
    self.sessionID = sessionID
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
    self.sharedKey = sharedKey
end

function user:updateActive()
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
end

return user