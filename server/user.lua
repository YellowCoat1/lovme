-- user object file
local userClass = Object:extend()

function userClass:new(clientID, sharedKey, sessionID)
    -- assert(client and sharedKey and sessionID, "AAAAAAAAAAAAAAAA (userclass creation failiure)")
    self.clientID = clientID
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
    self.sessionID = sessionID
    self.sharedKey = sharedKey
end

function userClass:updateTimeout()
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
end

return userClass