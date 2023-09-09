-- user object file
local user = Object:extend()

function user:new(clientID, sharedKey)
    self.clientID = clientID
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
    self.sharedKey = sharedKey
end

function user:updateActive()
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
end

return user