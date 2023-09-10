-- user object file
local user = Object:extend()

function user:new(sessionID, sharedKey, client)
    self.client = client
    self.sessionID = sessionID
    self.sharedKey = sharedKey
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
end

function user:updateActive()
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
end

return user