-- user object file
local user = Object:extend()

function user:new(clientID, sharedKey)
    self.clientID = clientID
    self.sharedKey = sharedKey
end

function user:updateTimeout()
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
end

return user